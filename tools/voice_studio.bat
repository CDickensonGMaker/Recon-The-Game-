@echo off
title RECONgame Voice Studio
cd /d "C:\Users\caleb\RECONgame"
echo ================================================================
echo   RECONgame VOICE STUDIO  (free - Piper + audio_dsp)
echo ----------------------------------------------------------------
echo   Type a line + ENTER to hear it.
echo   'voice ryan'  switch voice   (ryan hfc_male joe john norman bryce
echo                                  hfc_female kristin
echo                                  vi_vais1000 vi_25hours vi_vivos)
echo   'profile radio' / 'profile field' / 'profile clean'
echo   blank line = quit
echo ================================================================
python tools\voice_studio.py --interactive --voice ryan --profile radio
pause
