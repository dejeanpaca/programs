{
   viewASCII, views ASCII character table and values
   Copyright (C) 2008. Dejan Boras

   Started On:    09.11.2008.
}

{$MODE OBJFPC}
PROGRAM viewASCII;

   USES
      sysutils,
      uStd, uLog, StringUtils, ConsoleUtils,
      uTVideo, video, keyboard, mouse;

VAR
   MouseOk: boolean;
   m: TMouseEvent;

   i,
   j,
   x,
   y,
   pmx,
   pmy: longint;

BEGIN
   log.InitStd('viewASCII.log', 'viewASCII', logcREWRITE);

   {initialize video}
   tvGlobal.Initialize();

   if(tvGlobal.Error <> 0) then begin
      log.e('Failed to initialize the video driver.');
      halt(1);
   end;

   {keyboard}
   InitKeyboard();

   {initialize the mouse and the keyboard}
   InitMouse();
   MouseOk := DetectMouse() > 0;

   if(tvGlobal.DC.ChangeMode) then begin
      {set the required video mode}
      tvGlobal.SetMode(tvcM40x25T);
      if(tvGlobal.error <> 0) then begin
         log.e('Failed to set 40x25 color video mode.');

         tvGlobal.SetMode(tvcM80x25T);
         if(tvGlobal.error <> 0) then begin
            log.e('Failed to set 80x25 color video mode.');
            halt(2);
         end;
      end;
   end;

   {display the characters}
   tvCurrent.SetBkColor(0);
   tvCurrent.SetColor(14);
   tvCurrent.Plot(0, 0, 'y');
   tvCurrent.Plot(33, 10, 'x');

   for i := 0 to 7 do begin
      tvCurrent.Plot(0, 1 + i, char(uint8('0') + i));
      tvCurrent.SetColor(15);

      for j := 0 to 31 do begin
         tvCurrent.Plot(2 + j, 1 + i, char((i * 32) + j));
      end;

      tvCurrent.SetColor(14);
   end;

   for i := 0 to 7 do begin
      tvCurrent.Plot(2 + i * 4, 9, #30);
      tvCurrent.Write(2 + i * 4, 10, sf(i * 4));
   end;

   tvCurrent.SetColor(15);
   {display version information}
   tvCurrent.Write(0, 16, 'Press any key to exit...');

   tvCurrent.SetColor(14);
   tvCurrent.Write(3, 13, 'Formula: # = (y * 32) + x');

   if(not MouseOk) then
      tvCurrent.Write(3, 15, 'Mouse device not available.');

   {update the screen}
   tvCurrent.Update();

   pmx := 0;
   pmy := 0;

   ZeroOut(m, SizeOf(m));

   {done}
   repeat
      if(MouseOk) then begin
         if(PollMouseEvent(m)) then begin
            GetMouseEvent(m);

            if(m.x <> pmx) or (m.y <> pmy) then begin
               pmx := m.x;
               pmy := m.y;

               if(m.y > 0) and (m.y < 9) and (m.x > 1) and (m.x < 34) then begin
                  x := m.x - 2;
                  y := m.y - 1;

                  tvCurrent.Write(3, 15, '#' + sf(y * 32 + x) + '(' + sf(y) + ':' + sf(x) + ')     ');
               end else
                  tvCurrent.Write(3, 15, '?             ');

               tvCurrent.Write(3, 14, sf(m.x) + 'x' + sf(m.y) + '     ');
               tvCurrent.Update();
            end;

            if(m.buttons <> 0) then begin
               log.i('user quit');

               break;
            end;
         end;
      end;

      Sleep(5);

      if(PollKeyEvent() <> 0) then begin
         GetKeyEvent();
         break;
      end;

   until (false);

   {done}

   DoneKeyboard();
   DoneMouse();
   tvGlobal.Deinitialize();

   console.Clear();
END.
