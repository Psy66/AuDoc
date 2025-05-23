# Audio Transcription with Whisper and Pyannote

Проект для автоматической транскрибации аудио с распознаванием спикеров, использующий:
- [OpenAI Whisper](https://github.com/openai/whisper) для распознавания речи
- [Pyannote](https://github.com/pyannote/pyannote-audio) для диаризации (разделения по спикерам)

## Особенности

✅ Автоматическое определение разных спикеров (диаризация)  
✅ Преобразование технических имен спикеров в "Персона 1", "Персона 2" и т.д.  
✅ Поддержка длинных аудиофайлов (автоматическая разбивка на 5-минутные сегменты)  
✅ Распознавание речи на русском языке  
✅ Автоматическая загрузка всех необходимых моделей при первом запуске  
✅ Подробное логирование процесса  

## Требования

- **ОС**: Windows 10/11 (64-bit) или Linux
- **Python**: 3.8+
- **Память**: 4+ GB RAM (рекомендуется 8+ GB)
- **Диск**: 5+ GB свободного места
- **Аудиоформат**: WAV (16kHz, моно)

## Подготовка машины

- запустить от имени Администратора prepare/install.bat
- следуйте инструкциям

## Быстрый старт

1. Установите зависимости:
   ```bash
   pip install torch torchaudio pydub tqdm pyannote.audio openai-whisper huggingface-hub
   ```

2. Поместите аудиофайл в корень проекта с именем `input.wav`

3. Запустите в консоле от имени Администратора:
   ```bash
   python audio_app.py
   ```

4. Результат будет сохранен в `output.txt`

## Конфигурация

Основные параметры (изменяются в конце файла `audio_app.py`):

```python
config = {
    'whisper_model': "tiny",  # Доступные модели: tiny, base, small, medium, large
    'whisper_dir': "models/whisper",  # Папка для моделей Whisper
    'pyannote_dir': "models/pyannote",  # Папка для моделей Pyannote
    'audio_file': "input.wav",  # Входной аудиофайл
    'output_file': "output.txt",  # Выходной файл
    'hf_token': "your_token"  # Токен Hugging Face
}
```

## Формат вывода

Результат сохраняется в формате:
```
SPEAKER_00 [10.2-15.7]: Привет, как дела?
SPEAKER_01 [15.8-20.3]: Привет! Все отлично.
```

## Важные заметки

🔹 Для работы Pyannote требуется токен Hugging Face (уже встроен в код)  
🔹 При первом запуске будут загружены модели:  
   - Whisper (~70-300MB в зависимости от модели)  
   - Pyannote (~2GB)  
🔹 Для обработки файлов длительностью >30 минут рекомендуется:  
   - Использовать модель Whisper medium/large  
   - Увеличить chunk_size в коде  

## Логирование

Все этапы работы записываются в консоль и в файл `transcriber.log`:
```
2025-04-08 12:00:00 - INFO - Downloading Pyannote models...
2025-04-08 12:00:05 - INFO - Processing chunks: 100%|████| 5/5 [02:15<00:00]
```

## Лицензия

MIT License. Модели Whisper и Pyannote имеют собственные лицензии.
