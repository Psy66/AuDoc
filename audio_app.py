import os
import torch
import time
from pyannote.audio import Pipeline
from whisper import load_model, transcribe, _download, _MODELS
from pydub import AudioSegment
from tqdm import tqdm
import logging
import warnings
import math
from huggingface_hub import snapshot_download, login, HfFolder

warnings.filterwarnings("ignore")
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class AudioTranscriber:
	# Preinstalled tokens
	DEFAULT_HF_TOKEN = "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"

	@staticmethod
	def get_relative_path(*path_parts):
		base_dir = os.path.dirname(os.path.abspath(__file__))
		return os.path.join(base_dir, *path_parts)

	@staticmethod
	def _download_whisper_model(model_name: str, download_root: str):
		"""Download Whisper model if not exists"""
		if model_name not in _MODELS:
			raise ValueError(f"Invalid model name: {model_name}. Available models: {', '.join(_MODELS.keys())}")

		os.makedirs(download_root, exist_ok=True)
		model_path = os.path.join(download_root, f"{model_name}.pt")

		if not os.path.exists(model_path):
			logger.info(f"Downloading Whisper model '{model_name}'...")
			try:
				_download(_MODELS[model_name], download_root, in_memory=False)
				logger.info(f"Model downloaded to: {model_path}")
			except Exception as e:
				logger.error(f"Failed to download Whisper model: {str(e)}")
				raise

		return model_path

	@staticmethod
	def _download_pyannote_model(model_dir: str, hf_token: str = None):
		"""Download Pyannote models with authentication and retry logic"""
		os.makedirs(model_dir, exist_ok=True)

		if not os.listdir(model_dir):
			logger.info("Downloading Pyannote models...")

			# Use HfFolder.get_token() if hf_token is not provided
			token = hf_token or HfFolder.get_token() or AudioTranscriber.DEFAULT_HF_TOKEN

			if not token:
				logger.warning("Pyannote model requires authentication...")
				logger.info("Please visit https://huggingface.co/pyannote/speaker-diarization")
				logger.info("Accept the agreement and create access token at https://huggingface.co/settings/tokens")
				token = input("Enter your Hugging Face access token: ").strip()

			login(token=token)

			max_retries = 10
			retry_delay = 5

			for attempt in range(max_retries):
				try:
					snapshot_download(
						"pyannote/speaker-diarization",
						cache_dir=model_dir,
						use_auth_token=True,
						resume_download=True,
						local_files_only=False
					)
					logger.info(f"Pyannote models downloaded to: {model_dir}")
					return
				except PermissionError as e:
					logger.warning(f"File access error (attempt {attempt + 1}/{max_retries}): {str(e)}")
					if attempt < max_retries - 1:
						logger.info(f"Retrying in {retry_delay} seconds...")
						time.sleep(retry_delay)
						continue
					raise
				except Exception as e:
					logger.error(f"Failed to download Pyannote models: {str(e)}")
					if "401" in str(e):
						logger.error("Invalid or expired token. Please check your Hugging Face token.")
					logger.error("You need to accept the license agreement at:")
					logger.error("https://huggingface.co/pyannote/speaker-diarization")
					raise

	@staticmethod
	def _load_whisper(model_name: str, model_dir: str):
		"""Load Whisper model with automatic download if needed"""
		model_path = AudioTranscriber._download_whisper_model(model_name, model_dir)
		return load_model(model_path)

	@staticmethod
	def _load_pyannote(model_dir: str, hf_token: str = None):
		"""Load Pyannote pipeline with automatic download if needed"""
		AudioTranscriber._download_pyannote_model(model_dir, hf_token)
		os.environ["PYANNOTE_CACHE"] = model_dir

		# Явно передаем токен в Pipeline
		token = hf_token or HfFolder.get_token() or AudioTranscriber.DEFAULT_HF_TOKEN
		if not token:
			raise ValueError("Hugging Face token is required for Pyannote")

		return Pipeline.from_pretrained(
			"pyannote/speaker-diarization",
			use_auth_token=token  # Передаем токен явно
		)

	@staticmethod
	def _process_segment(audio, start, end, speaker, model):
		temp_path = AudioTranscriber.get_relative_path(f"temp_{start:.0f}_{end:.0f}.wav")
		audio[int(start * 1000):int(end * 1000)].export(temp_path, format="wav")
		result = transcribe(model, temp_path, language="ru", fp16=False)
		os.remove(temp_path)
		return {"start": start, "end": end, "speaker": speaker, "text": result["text"]}

	@staticmethod
	def run(config):
		torch.set_num_threads(4)

		try:
			logger.info("Initializing models...")

			# Create models directories if not exist
			os.makedirs(AudioTranscriber.get_relative_path(config['whisper_dir']), exist_ok=True)
			os.makedirs(AudioTranscriber.get_relative_path(config['pyannote_dir']), exist_ok=True)

			# Load models with automatic downloads
			whisper = AudioTranscriber._load_whisper(
				config['whisper_model'],
				AudioTranscriber.get_relative_path(config['whisper_dir'])
			)

			pipeline = AudioTranscriber._load_pyannote(
				AudioTranscriber.get_relative_path(config['pyannote_dir']),
				hf_token=config.get('hf_token')
			)

			# Check audio file exists
			if not os.path.exists(AudioTranscriber.get_relative_path(config['audio_file'])):
				raise FileNotFoundError(f"Audio file not found: {config['audio_file']}")

			audio = AudioSegment.from_wav(AudioTranscriber.get_relative_path(config['audio_file']))
			chunk_size = 5 * 60 * 1000
			chunks = math.ceil(len(audio) / chunk_size)
			results = []

			with tqdm(total=chunks, desc="Processing chunks") as pbar:
				for i in range(0, len(audio), chunk_size):
					chunk_path = AudioTranscriber.get_relative_path(f"temp_chunk_{i // chunk_size}.wav")
					audio[i:i + chunk_size].export(chunk_path, format="wav")

					diarization = pipeline(chunk_path)
					segments = [(s.start, s.end, sp) for s, _, sp in diarization.itertracks(yield_label=True)]

					with tqdm(segments, desc="Transcribing", leave=False) as seg_pbar:
						results.extend([AudioTranscriber._process_segment(
							AudioSegment.from_wav(chunk_path), s[0], s[1], s[2], whisper) for s in seg_pbar])

					os.remove(chunk_path)
					pbar.update(1)
					pbar.set_postfix_str(f"Segments: {len(results)}")

			output_path = AudioTranscriber.get_relative_path(config['output_file'])
			with open(output_path, "w", encoding="utf-8") as f:
				f.writelines(f"{r['speaker']} [{r['start']:.1f}-{r['end']:.1f}]: {r['text']}\n" for r in results)

			logger.info(f"Completed! Results saved to: {output_path}")

		except Exception as e:
			logger.error(f"Error: {str(e)}")
			raise

if __name__ == "__main__":
	config = {
		'whisper_model': "tiny",  # Whisper model (tiny, base, small, medium, large)
		'whisper_dir': "models/whisper",  # Directory for Whisper models
		'pyannote_dir': "models/pyannote",  # Directory for Pyannote models
		'audio_file': "input.wav",  # Input audio file
		'output_file': "output.txt",  # Output text file
		'hf_token': "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"  # Your Hugging Face access token
	}
	AudioTranscriber.run(config)
