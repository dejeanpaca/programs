{
   q2Unpak, a console program to unpack Quake II .pak files
   Copyright (C) 2007. - 2010. Dejan Boras

   Started On:    14.12.2007.
}

{$MODE OBJFPC}{$H+}{$I-}
PROGRAM q2UnPak;

{A console program to unpack Quake II .pak files}

   USES StringUtils, uStd, uFile, uFiles, uBinarySize;

CONST
   dcProgramName                       = 'q2UnPak';
   dcProgramVersion                    = $0100;

   {signature a pak file must have to be identified as a pak file}
   pakcSignature: array[0..3] of char  = ('P', 'A', 'C', 'K');

   eNOT_PAK                            = $100; {not a q2 pak file}

   ShowFileProgress: boolean           = false;

TYPE
   {header in a pak file}
   pakTHeader = record
      Signature: array[0..3] of char;
      dOffset: longword;
      dLength: longword;
   end;

   {file entry in the directory section}
   pakTEntry = record
      fName: string[55];
      Position, Length: longword;
   end;

VAR
   fPak: TFile; {pak file}
   fSize,
   fPos: uint64;
   fName,
   prevDir: string; {filename}
   nEntries: longword;

   hdr: pakTHeader;

procedure eRaise(e: longint);
begin
   fPak.Error := e;
end;

procedure eReset();
begin
   fPak.Error := 0;
end;

{READING HELPER ROUTINES}

{read the header from the pak file}
procedure readHeader();
begin
   {read in the header}
   fPak.Read(hdr, SizeOf(pakTHeader));

   {check the header}
   if(hdr.Signature <> pakcSignature) then begin
      writeln;
      writeln('Error: The file is either not a Quake II PAK file or is corrupted.');
      eRaise(eNOT_PAK);
      exit;
   end;

   if(hdr.dOffset = 0) or (hdr.dLength = 0) then begin
      writeln;
      writeln('Error: The directory information is not valid or corrupted.');
      eRaise(eINVALID);
      exit;
   end;

   {get the number of entries in the directory section}
   nEntries := hdr.dLength div SizeOf(pakTEntry);

   if(nEntries < 1) then begin
      writeln;
      writeln('Error: The number of directory entries is invalid (0).');
      eRaise(eINVALID);
      exit;
   end;
end;

{unpacks a file from the pak file}
procedure unPakEntry(var entry: pakTEntry);
var
   data: pointer = nil;
   f: file;
   dir, 
   prevsubdir, 
   subdir, 
   tempdir, 
   tmppath: string;
   foundBackSlashes, 
   subdircount, 
   diff, 
   _pos, 
   i: longint;

procedure CleanUpFile();
begin
   Close(f);
   if(ioerror <> 0) then begin
      writeln('Warning: Cannot close the new file. A file handle may not be freed');
      writeln('and not all data may be written to the file causing data loss.');
      exit;
   end;
end;

procedure CleanUpMem();
begin
   if(data <> nil) then 
      FreeMem(data);
end;

procedure CleanUp();
begin
   CleanUpFile(); 
   CleanUpMem();
end;

begin
   {go to the position of the file described in entry}
   fPak.Seek(entry.Position);
   if(fPak.Error <> 0) then begin
      writeln('Error: Can not seek to the position of the packed file.'); 
      exit;
   end;

   {first fix the filename}
   tmppath := entry.fName;
   ReplaceDirSeparators(tmppath);
   entry.fName := tmppath;

   foundBackSlashes := 0;
   _pos := 0; 
   diff := pos('..', entry.fName);
   if(diff > 0) then begin
      for i := diff downto 1 do begin
         if(entry.fName[i] = DirectorySeparator) then begin
            inc(foundBackSlashes);
            if(foundBackSlashes = 2) then begin 
               _pos := i;
               break; 
            end;
         end;
      end;
   end;
   
   if(_pos <> 0) then begin
      delete(entry.fName, _pos, diff-_pos + 2);
   end;

   {get the file directory and name}
   dir := ExtractFileDir(entry.fName);

   tempdir := dir;

   prevsubdir := ''; 
   subdircount := 0;
   {extract one subdir after another}
   repeat
      subdir := CopyToDel(tempdir, DirectorySeparator);
      inc(subdircount);
      if(prevsubdir <> '') then
         chdir(prevsubdir);
      mkdir(subdir);
      if(ioerror <> 0) then begin 
         {ignore failing to create a directory for now}
      end; 
      prevsubdir := subdir;
   until (Length(tempdir) = 0);

   if(subdircount > 1) then
      for i := 2 to subdircount do 
         chdir('..');

   {get memory for the file in the pak}
   GetMem(data, entry.Length);
   if(data = nil) then begin
      writeln('Error: Insufficient memory.'); 
      eRaise(eNO_MEMORY); 
      exit;
   end;

   {read the file from the pak}
   fPak.Read(data^, entry.Length);
   if(fPak.Error <> 0) then begin
      writeln('Error: Can not read a packed file from the pak file.');
      CleanUpMem(); 
      eRaise(eIO); 
      exit;
   end;

   {create the new file}
   Assign(f, entry.fName);
   Rewrite(f, 1);
   if(ioerror <> 0) then begin
      writeln('Error: Cannot create a new file: ', entry.fName, ' | eIO: ', ioE);
      eRaise(eIO); 
      exit;
   end else begin
      {write the data to the file}
      blockwrite(f, data^, entry.Length);
      if(ioerror <> 0) then begin
         writeln('Error: Cannot write to new file. Out of disk space?');
         eRaise(eIO); 
         CleanUp(); 
         exit;
      end;

      CleanUpFile();
   end;

   {finished}
   CleanUpMem();
end;

{reads all the entries from the pak file}
procedure readEntries();
var
   i: longword;
   entry: pakTEntry;
   pos: uint64;

begin
   {go to the position of the directory data in the file}
   fPak.Seek(hdr.dOffset);

   ZeroPtr(@entry, SizeOf(entry));

   {read one by one entry}
   for i := 0 to nEntries-1 do begin
      fPak.Read(entry, SizeOf(pakTEntry));
      if(fPak.Error <> 0) then
         exit;

      pos := fPos;

      {convert the name from an ANSI string to a pascal string}
      entry.fName := PCharToShortString(@entry.fName[0]);
      if(ShowFileProgress = true) then
         writeln('Unpacking: ', entry.fName);

      unPakEntry(entry);

      {return back to the last position in the directory}
      fPak.Seek(pos);
   end;
end;

procedure UnPak();
begin
   eReset();

   {initialize}
   fSize := 0; 
   fPos := 0; 
   prevDir := '';

   {open the file}
   write('Opening file...');

   fFile.Init(fPak);

   fPak.Open(fName);

   if(fPak.Error <> 0) then
      exit;

   fSize := fPak.GetSize();
   if(fPak.Error <> 0) then begin
      fPak.Close();
      exit;
   end;

   writeln(' OK');

   {read the header}
   write('Reading header...');

   readHeader();
   if(fpak.Error <> 0) then
      exit;

   writeln(' OK');

   writeln('Total file data: ', getiecByteSizeHumanReadable(fSize - (hdr.dLength + SizeOf(pakTHeader))));

   {go to the directory section and read one entry after another}
   writeln('Reading directory entries...');

   readEntries();

   {close the file}
   write('Closing file...');

   fPak.Close();
   if(fPak.Error <> 0) then begin
      writeln('Warning: Unable to close the file.');
      exit;
   end;

   writeln(' OK');
end;

BEGIN
   writeln(dcProgramName, ' v', hi(dcProgramVersion), '.' ,Lo(dcProgramVersion));
   writeln('Copyright (c) Dejan Boras 2007.');
   writeln();

   {check the arguments}
   fName := paramstr(1);
   if(fName = '') then begin
      writeln('Missing arguments. Need to specify filename.');
      halt(0);
   end else if (fName = '-?') then begin
      writeln('q2UnPak [filename]');
      writeln();
      writeln('filename - name of the quake 2 .pak file to be unpacked');
      halt(0);
   end;

   UnPak();
   writeln;
END.
