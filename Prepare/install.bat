@echo off
chcp 1251 > nul
:: ================================================
:: Установка среды для аудио-транскрибации
:: ================================================
::
:: Этот скрипт установит:
:: - Chocolatey (менеджер пакетов)
:: - FFmpeg и CMake
:: - Python и библиотеки (Whisper, Pyannote и др.)
::
:: Время установки: от 5 до 25 минут
:: Требуется: 5+ GB места, интернет, права админа
:: ================================================

echo.
echo ВНИМАНИЕ: Этот скрипт установит программное обеспечение
echo          и внесет изменения в систему.
echo.
echo Проверьте что у вас:
echo - Достаточно места на диске
echo - Стабильное интернет-подключение
echo - Закрыты все важные программы
echo.
echo Продолжить установку? (Да/Нет)
choice /c ДН /n /m "Ваш выбор: "
if errorlevel 2 goto :cancel

echo.
echo Запуск установки с правами администратора...
echo (Подтвердите запрос контроля учетных записей)
echo.

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0setup.ps1""' -Verb RunAs"
goto :exit

:cancel
echo.
echo Установка отменена пользователем.
pause
exit /b 1

:exit
exit /b 0