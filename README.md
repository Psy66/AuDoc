# Audio Transcription with Whisper and Pyannote

Проект для автоматической транскрибации аудио с распознаванием спикеров, использующий:
- [OpenAI Whisper](https://github.com/openai/whisper) для распознавания речи
- [Pyannote](https://github.com/pyannote/pyannote-audio) для диаризации (разделения по спикерам)

## Особенности

- Поддержка длинных аудиофайлов (автоматическая разбивка на чанки)
- Распознавание речи на русском языке
- Идентификация спикеров
- Поддержка как CPU, так и GPU (CUDA)
- Подробное логирование процесса

## Требования

- Windows 10/11 (64-bit)
- Python 3.8+
- 4+ GB RAM (рекомендуется 8+ GB)
- 5+ GB свободного места на диске
- Для GPU: NVIDIA карта с поддержкой CUDA 11.7+

## Установка

1. **Автоматическая установка** (рекомендуется):
   - Запустите `install.bat` из папки `prepare`
   - Подтвердите запрос UAC (требуются права администратора)
   - Дождитесь завершения (5-25 минут)

2. **Ручная установка**:
   - Установите [Chocolatey](https://chocolatey.org/install)
   - Установите зависимости:
     ```cmd
     choco install -y ffmpeg cmake --version=3.31.6
     ```
   - Установите Python пакеты:
     ```cmd
     pip install torch torchaudio ffmpeg-python librosa>=0.10.0 openai-whisper>=20231106 pyannote.audio>=3.1 soundfile
     ```

## Использование

1. Поместите аудиофайл (в формате WAV) в корень проекта с именем `input.wav`
2. Запустите:
   ```cmd
   python main.py
   ```
3. Результат будет сохранен в output.txt

## Конфигурация
Измените параметры в блоке config в конце main.py:
  ```cmd
  config = {
      'whisper_path': os.path.join("models", "whisper", "medium.pt"),  # Путь к модели Whisper
      'pyannote_segmentation_dir': os.path.join("models", "pyannote", "segmentation"),  # Кеш для Pyannote
      'audio_file': "input.wav",  # Входной файл
      'output_file': "output.txt"  # Выходной файл
  }
  ```
## Поддерживаемые модели Whisper
tiny, base, small, medium, large (рекомендуется medium для баланса качества/скорости)

## Примечания
Для первого запуска Pyannote загрузит предобученные модели (~2GB)

Для работы с GPU убедитесь что установлены драйверы NVIDIA CUDA Toolkit

Для обработки длинных файлов (>30 минут) рекомендуется использовать GPU

## Логирование
Процесс транскрибации записывается в transcriber.log с детальной информацией.

## Лицензия
Проект распространяется под MIT License. Используемые библиотеки имеют свои собственные лицензии.

