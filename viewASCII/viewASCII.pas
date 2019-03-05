{
   viewASCII, views ASCII character table and values
   Copyright (C) 2008. Dejan Boras

   Started On:    09.11.2008.
}

{$MODE OBJFPC}
PROGRAM viewASCII;

   USES
      Keyboard, Mouse, Video, StringUtils,
      uTVideo, uTVideoImg;

CONST
   dcProgramName: string      = 'viewASCII';
   dcProgramVersion           = $0100;

   vMode: TVideoMode          = (col: 40; row: 25; color: true);
   vMode2: TVideoMode         = (col: 80; row: 25; color: true);

   MouseOk: boolean           = false;

VAR
   i, j: longint;
   x, y, mx, my, pmx, pmy: longint;

LABEL
   lbl_finished;

BEGIN
  {initialize the mouse and the keyboard}
  InitMouse();
  MouseOk := DetectMouse > 0;

  InitKeyboard();

  {initialize video}
   tvGlobal.Initialize();
   if(tvGlobal.error <> 0) then begin
      writeln('Error: Failed to initialize the video driver.');
      halt(1);
   end;

   if(tvGlobal.DC.ChangeMode) then begin
      {set the required video mode}
      tvGlobal.SetMode(vMode);
      if(tvGlobal.error <> 0) then begin
         writeln('Error: Failed to set 40x25 color video mode.');

         tvGlobal.SetMode(vMode2);
         if(tvGlobal.error <> 0) then begin
            writeln('Error: Failed to set 80x25 color video mode.');
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
   tvCurrent.Write(3, 12, dcProgramName +
         ' v' + sf(hi(dcProgramVersion)) + '.' + sf(lo(dcProgramVersion)));
   tvCurrent.Write(3, 13, 'Copyright (c) 2009. Dejan Boras');

   tvCurrent.Write(3, 15, 'This program is open source under');
   tvCurrent.Write(3, 16, 'GNU GPLv3. See license for details.');

   tvCurrent.Write(0, 24, 'Press any key to exit...');

   tvCurrent.SetColor(14);
   tvCurrent.Write(3, 21, 'Formula: # = (y*32)+x');
   if(not MouseOk) then
      tvCurrent.Write(3, 22, 'Mouse device not available.');

   {update the screen}
   UpdateScreen(false);

   pmx := 0;
   pmy := 0;

   {done}
   repeat
      if(MouseOk) then begin
         mx := GetMouseX();
         my := GetMouseY();
         if(mx <> pmx) or (my <> pmy) then begin
            pmx := mx;
            pmy := my;

            if(my > 0) and (my < 9) and (mx > 1) and (mx < 34) then begin
               x := mx - 2;
               y := my - 1;

               tvCurrent.Write(3, 22, '#' + sf(y * 32 + x)+'('+sf(y) + ':' + sf(x) + ')     ');
            end else
               tvCurrent.Write(3, 22, '?             ');

            UpdateScreen(false);
         end;
         if(GetMouseButtons() <> 0) then
            goto lbl_finished;
      end;
   until (Keypressed() = true);

lbl_finished:

   {done}
   tvCurrent.Clear();
   UpdateScreen(false);
   DoneKeyboard();
   DoneMouse();
   tvGlobal.Deinitialize();
END.

