@echo off
chcp 1251 > nul
:: ================================================
:: ��������� ����� ��� �����-�������������
:: ================================================
::
:: ���� ������ ���������:
:: - Chocolatey (�������� �������)
:: - FFmpeg � CMake
:: - Python � ���������� (Whisper, Pyannote � ��.)
::
:: ����� ���������: �� 5 �� 25 �����
:: ���������: 5+ GB �����, ��������, ����� ������
:: ================================================

echo.
echo ��������: ���� ������ ��������� ����������� �����������
echo          � ������ ��������� � �������.
echo.
echo ��������� ��� � ���:
echo - ���������� ����� �� �����
echo - ���������� ��������-�����������
echo - ������� ��� ������ ���������
echo.
echo ���������� ���������? (��/���)
choice /c �� /n /m "��� �����: "
if errorlevel 2 goto :cancel

echo.
echo ������ ��������� � ������� ��������������...
echo (����������� ������ �������� ������� �������)
echo.

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0setup.ps1""' -Verb RunAs"
goto :exit

:cancel
echo.
echo ��������� �������� �������������.
pause
exit /b 1

:exit
exit /b 0