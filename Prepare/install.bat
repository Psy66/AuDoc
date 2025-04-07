@echo off
chcp 1251 > nul
:: ================================================
:: Установка среды для аудио-транскрибации
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
echo Продолжить установку? (Y/N)
choice /c YN /n /m "Ваш выбор [Y,N]? "
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
