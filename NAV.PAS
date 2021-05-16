{
 NAV: A fast mode to navigate between folders and execute files

 Copyright 2019-2021 XWolfOverride

 Licensed under the MIT License

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 and associated documentation files (the "Software"), to deal in the Software without restriction,
 including without limitation the rights to use, copy, modify, merge, publish, distribute,
 sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or
 substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

Program fast_navigator;

{$M 4096,0,0}

{_$DEFINE TEXT_READER} {WIP!!}
{_$DEFINE LOWRAM}

uses TUI,DOS,XWMem;

type
 TFileName=string[12];
 TFileType=(ftDirectory,ftExecutable,ftBatch,ftOther);
 TFileRecord=record
  name:TFileName;
  kind:TFileType;
 end;

const

{$IFDEF LOWRAM}
 MaxFiles=128;
{$ELSE}
{$IFDEF TEXT_READER}
 MaxFiles=1024;
{$ELSE}
 MaxFiles=512;
{$ENDIF}
{$ENDIF}
 attrBox:byte=$1f;
 attrItm:byte=$1f;
 attrIex:byte=$12;
 attrIba:byte=$13;
 attrIot:byte=$17;
 attrSel:byte=$2f;
 attrSrc:byte=$1e;

var
{$IFDEF LOWRAM}
{$ELSE}
 InitialScreen:array[0..4000] of word;
{$ENDIF}
 ScreenMode:TScreenMode;
 Dir:string;
 Files:Array[0..MaxFiles] of TFileRecord;
 Max:integer;
 Scroll,Selection:integer;
 Columns:byte;
 Search:TFileName;

procedure DrawUI(full:boolean); forward;
procedure Init; forward;
procedure Done; forward;

{Return the name with the extension aligned}
function  Filename12(name:TFileName):TFileName;
var i,p:integer;
    ext:TFileName;
begin
 p:=Pos('.',name);
 if p>0 then begin
  ext:=Copy(name,p+1,3);
  name[0]:=#12;
  for i:=p to 12 do name[i]:=' ';
  Insert(ext,name,10);
 end else begin
  for i:=Length(name)+1 to 12 do name[i]:=' ';
  name[0]:=#12;
 end;
 Filename12:=name;
end;

{Add a record to the record list}
procedure AddRecord(name:TFileName;kind:TFileType);
var
 i,p:integer;
 brk:boolean;
begin
 if Max=MaxFiles then
  exit;
 i:=0;
 while i<=Max do begin
  brk:=(kind<Files[i].kind) or
       ((kind=Files[i].kind) and (name<=Files[i].name));
  if brk then
   break
  else
   inc(i);
 end;
 p:=i;
 for i:=Max downto p do
  Files[i+1]:=Files[i];

 inc(Max);
 Files[p].name:=name;
 Files[p].kind:=kind;
end;

{Scan directory}
procedure ReadDirectory;
var
 t:searchrec;
 name:TFileName;
 ext:string[3];
begin
 GetDir(0,Dir);
 Max:=-1;
 FindFirst('*.*',directory,T);
 while doserror=0 do begin
  if (t.name<>'.') and (t.name<>'..') then begin
   name:=Filename12(t.name);
   ext:=copy(name,10,3);
   if (t.attr and directory)<>0 then
    AddRecord(name,ftDirectory)
   else if (ext='EXE') or (ext='COM') then
    AddRecord(name,ftExecutable)
   else if ext='BAT' then
    AddRecord(name,ftBatch)
{$IFDEF TEXT_READER}
   else
    AddRecord(name,ftOther)
{$ENDIF}
   ;
  end;
  FindNext(t);
 end;
 Selection:=0;Scroll:=0;
end;

{$IFDEF TEXT_READER}
{Open a file for reading}
procedure FileView(path:string);
var
 f:file of byte;
 b:byte;
begin
 DrawBox(1,1,ScreenInfo.width-2,ScreenInfo.height-2,bmText,$4F,true);
{$I-}
 Assign(f,path);
 FileMode:=0;
 Reset(f);
 Read(f,b);
 GetKey;
 Close(f);
{$I+}
 RestoreScreen(InitialScreen);
 DrawUI(true);
end;
{$ENDIF}

{Executes the selected file, if file is an executable executes it,
 if a directory reads it}
procedure Endrejuta(fil:TFileRecord);
var
 path:string;
 name:TFileName;
 i,p:integer;
 fattr:word;
begin
 Search:='';
 {Path preparation}
 path:=Dir;
 if path[length(path)]<>'\' then
  path:=path+'\';
 {Name standarization}
 name:=fil.name;
 p:=Pos(' ',name);
 if name[10]<>' ' then begin
  name[0]:=char(p);
  name[p]:='.';
  for i:=10 to 12 do
   if name[i]<>' ' then
    name:=name+name[i];
 end else
  name[0]:=char(p-1);
 {Detect directory or executable}
 path:=path+name;
 case fil.kind of
 ftDirectory:begin
  chdir(path);
  ReadDirectory;
  DrawUI(true);
 end;
 ftExecutable:begin
  Done;
  SwapVectors;
  Exec(path,'');
  SwapVectors;
  Init;
  ReadDirectory;
  DrawUI(true);
 end;
 ftBatch:begin
  Done;
  SwapVectors;
  Exec(GetEnv('COMSPEC'),'/C '+path);
  SwapVectors;
  Init;
  ReadDirectory;
  DrawUI(true);
 end;
{$IFDEF TEXT_READER}
 ftOther:begin
  FileView(path);
 end;
{$ENDIF}
 end;
end;

{Goes back on the directory listing}
procedure Patra;
var
 path:string;
begin
 {Path preparation}
 path:=Dir;
 if path[length(path)]<>'\' then
  path:=path+'\';
 {Change directory}
 path:=path+'..';
 chdir(path);
 ReadDirectory;
 DrawUI(true);
end;

{Draw the UI for the current directory}
procedure DrawUI(full:boolean);
var
 x,y,w,h,rows,attr,col,row:byte;
 title:string[80];
 i,soffset:integer;
 charinfo:word;
 sinput:TFileName;
begin
 case ScreenMode of
 smLow:begin
  x:=1;
  y:=1;
  w:=29;
  h:=23;
  Columns:=2;
 end;
 smNormal:begin
  x:=2;
  y:=1;
  w:=44;
  h:=23;
  Columns:=3;
 end;
 smHigh:begin
  x:=2;
  y:=2;
  w:=59;
  h:=ScreenInfo.height-(y+2);
  Columns:=4;
 end;
 end;
 rows:=h-3;
 if full then begin
  {Draw box}
  DrawBox(x,y,w,h,bmSingle,attrBox,true);
  {Draw title}
  title:=dir;
  if length(title)>w-3 then begin
   title:='...'+copy(title,length(title)-(w-8),w-7);
  end;
  title:='['+title+']';
  DrawString(x+1,y,title,attrIot);
  charinfo:=GetCharInfo(#179,attrIot);
  for i:=y+1 to (h+y)-2 do
   for col:=0 to Columns-2 do
    DrawChar((x+14)+(col*15),i,charinfo);
 end;
 {Draw items}
 inc(x);
 inc(y);
 if (Selection div Columns)<Scroll then
  Scroll:=Selection div Columns;
 if (Selection div Columns)>(Scroll+rows) then
  Scroll:=(Selection div Columns)-rows;

 soffset:=Scroll*Columns;
 for i:=soffset to Max do begin
  col:=i mod Columns;
  row:=(i div Columns)-Scroll;
  if row>Rows then break;
  if i=Selection then
   attr:=attrSel
  else case Files[i].kind of
   ftDirectory:  attr:=attrItm;
   ftExecutable: attr:=attrIex;
   ftBatch:      attr:=attrIba;
   ftOther:      attr:=attrIot;
  end;
  DrawString(x+(15*col),y+row,Files[i].name,attr);
 end;
 if row<=Rows then
  for i:=col+1 to Columns-1 do begin
   DrawString(x+(15*i),y+row,'            ',attrItm);
  end;
  sinput[0]:=#12;
 FillB(sinput[1],12,byte('_'));
 CopyB(Search[1],sinput[1],length(Search));
 DrawString(x,(y+h)-2,' '+sinput+' ',attrSrc);
end;

{Handles the search box}
procedure DoSearch(ch:char);
var
 i,ln:integer;
begin
 if ch=#8 then begin
  Search[0]:=char(byte(Search[0])-1);
 end else
  Search:=Search+UpCase(ch);
 ln:=length(Search);
 if ln>0 then begin
  for i:=0 to Max do
   if copy(Files[i].name,1,ln)=Search then begin
    Selection:=i;
    break;
   end;
 end;
 DrawUI(false);
end;

{Process one command step (return false to exit the application)}
function Command:boolean;
var k:char;
begin
 k:=GetKey;
 if k=#0 then begin
  k:=GetKey;
  case k of
   #80:begin
    inc(Selection,Columns);
    if Selection>Max then
     Selection:=Max;
    Search:='';
   end;
   #72:begin
    dec(Selection,Columns);
    if Selection<0 then
     Selection:=0;
    Search:='';
   end;
   #77:begin
    inc(Selection);
    if Selection>Max then
     Selection:=Max;
    Search:='';
   end;
   #75:begin
    dec(Selection);
    if Selection<0 then
     Selection:=0;
    Search:='';
   end;
  end;
  k:=#0;
 end;
 case k of
  #0:; {Fast trap of special key, only for case speedup}
  #13:Endrejuta(Files[Selection]);
  #8 :if length(search)>0 then DoSearch(k) else Patra;
  'a'..'z','A'..'Z','0'..'9','!','.','_','%': DoSearch(k);
 end;
 Command:=k<>#27;
end;

{Initializes the application}
procedure Init;
begin
 ScreenMode:=GetScreenMode;
 if ScreenMode=smUnknown then begin
  SetScreenMode(smNormal);
  ScreenMode:=GetScreenMode;
 end;
 Search:='';
{$IFDEF LOWRAM}
 SetCursorPosition(0,0);
{$ELSE}
 SaveScreen(InitialScreen);
{$ENDIF}
end;

{Finalizes the application and restore the initial screen}
procedure Done;
begin
{$IFDEF LOWRAM}
 ClearScreen;
{$ELSE}
 RestoreScreen(InitialScreen);
{$ENDIF}
end;

{Application loop}
procedure Execute;
begin
 ReadDirectory;
 DrawUI(true);
 while Command do
  DrawUI(false);
end;

{Entry point}
var
 ch:char;
begin
 Init;
 Execute;
 Done;
end.