import os
import torch
from pyannote.audio import Pipeline
from whisper import load_model, transcribe
from pydub import AudioSegment
from tqdm import tqdm
import logging
import warnings
import math

warnings.filterwarnings("ignore")
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class AudioTranscriber:
	@staticmethod
	def get_relative_path(*path_parts):
		base_dir = os.path.dirname(os.path.abspath(__file__))
		return os.path.join(base_dir, *path_parts)

	@staticmethod
	def _load_model(path):
		if not os.path.exists(path):
			raise FileNotFoundError(f"Model not found: {path}")
		return load_model(path)

	@staticmethod
	def _init_pipeline(segmentation_dir):
		os.environ["PYANNOTE_CACHE"] = segmentation_dir
		return Pipeline.from_pretrained("pyannote/speaker-diarization", use_auth_token=False)

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
			whisper = AudioTranscriber._load_model(AudioTranscriber.get_relative_path(config['whisper_path']))
			pipeline = AudioTranscriber._init_pipeline(
				AudioTranscriber.get_relative_path(config['pyannote_segmentation_dir']))

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
		'whisper_path': os.path.join("models", "whisper", "medium.pt"),
		'pyannote_segmentation_dir': os.path.join("models", "pyannote", "segmentation"),
		'audio_file': "input.wav",
		'output_file': "output.txt"
	}
	AudioTranscriber.run(config)