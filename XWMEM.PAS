unit XWMem; {Memory Management Unit by XWolf}
{$G-}

INTERFACE

procedure CopyB(var source,target;count:word);
procedure CopyW(var source,target;count:word);
procedure CopyD(var source,target;count:word);
procedure FillB(var target;len:word;val:byte);
procedure FillW(var target;len:word;val:word);

IMPLEMENTATION

procedure CopyB(var source,target;count:Word); assembler;
asm
   mov  bx,ds
   lds  si,source
   les  di,target
   mov  cx,count
   {db   $f3,$66,$a5    {rep movsd}
   rep  movsb     {movs --> movsb (byte) Mueve un byte |movsw (Word) Mueve un word}
   mov  ds,bx
end;

procedure CopyW(var source,target;count:word); assembler;
asm
   mov  bx,ds
   lds  si,source
   les  di,target
   mov  cx,count
   {db   $f3,$66,$a5    {rep movsd}
   rep  movsw     {movs --> movsw (byte) Mueve un word |movsd (Double) Mueve un LongWord}
   mov  ds,bx
end;

procedure CopyD(var source,target;count:word); assembler;
asm
   mov  bx,ds
   lds  si,source
   les  di,target
   mov  cx,count
   db   $f3,$66,$a5    {rep movsd}
   mov  ds,bx
end;

(*
procedure Fliper(VAR desde,hasta;Len:Word); Assembler; {Copia optimizada}
 asm
  mov bx,ds
  lds si,desde
  les di,hasta
  mov cx,Len
  shr cx,2
  db  $f3,$66,$a5    {rep movsd}
  mov cx,len
  and cx,3
  cmp cx,0
  je @salil
  rep movsb
  @salil:
  mov ds,bx
 end;

procedure OffFlip (VAR desde,hasta;Len:Word;Off:Byte); Assembler;
asm
   mov bx,ds
   lds si,desde
   les di,hasta
   mov cx,Len
   @loop:
   dec cx
   mov al,[ds:si]
   cmp al,off {Byte-off}
   jz @Lorp  {Jump if Byte=off}
    movsb
   jmp @ltest {Test continue}
   @Lorp:     {Next without mov}
    inc si
    inc di
   @ltest:    {Continue?}
   cmp cx,0
   jnz @Loop
   mov ds,bx
end;
*)

procedure FillB(var target;len:word;val:byte); assembler;
asm
  mov  bx,ds
  les  di,target
  mov  ah,val
  mov  al,val
  mov  cx,len
  rep  stosb
  mov  ds,bx
end;

procedure FillW(var target;len:word;val:word); assembler;
asm
  mov  bx,ds
  les  di,target
  mov  ax,val
  mov  cx,len
  rep  stosw
  mov  ds,bx
end;


begin
end.