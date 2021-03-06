{$title: 'Command Line Filename Parser' $linesize:79}
MODULE parse;   {$debug- $stackck+}
{ command line filename parsing;  Bob Wallace Microsoft 7/81 }
CONST maxfile = 32;   {NOTE: must be set same as caller}  


                  dfprf = 'PRF'; 
                  msprf = 'Profile filename [';
                  dfhst = 'HST';
                  mshst = 'Histogram filename [';
                  dfmap = 'MAP';
                  msmap = 'Map file  [';
                  nuln = 'NUL     ';

TYPE
  filenam = lstring (maxfile);       {filename parameter type}
  setsw = ARRAY [wrd(0)..3] OF byte; {switches parameter type}
  sets = set of 0..31;               {caller's parameter type}
  setc = set of chr(0)..chr(127);    {set of characters}
  cpmex = string (3);  cpmnm = string (8);
  cpmfn = RECORD
            cfd [0]: string (2);
            cfn [2]: cpmnm;  cfp [10]: char;  cfe [11]: cpmex;
          END;
  setbitt = ARRAY [wrd(0)..7] OF byte;
CONST setbit = setbitt (128, 64, 32, 16, 8, 4, 2, 1);

VAR idset:setc; VALUE idset:=setc ['A'..'Z','a'..'z','0'..'9',
            '$', '&', '#', '@', '!', '%', '-', '_', '`', '''',
            '(', ')', '<', '>', '{', '}', '\', '^', '~', '|'];
VAR drset:setc; VALUE drset:=setc ['A'..'O','a'..'o'];

PROCEDURE fillc (dst: adrmem; len: word;  chc: char);  extern;
PROCEDURE movel (prf: adrmem; dst: adrmem; len: word); extern;
PROCEDURE ptyuqq (len: word; prf: adsmem);             extern;
PROCEDURE plyuqq;                                      extern;
FUNCTION gtyuqq (len: word; dst: adsmem): word;        extern;

PROCEDURE filbm 
(VAR prffil,hstfil,mapfil: filenam;  VAR oldsw: setsw);
(* sets the filenames for source, hstect, listing, and second
 listing (hstect list or cross ref);  also sets any switches,
 allowing those in the oldsw set and returning them in oldsw *)
VAR prf, hst, map: cpmfn; {target filenames in CPM format}
  newsw: setsw;                {new switches, return in oldsw}
  qq: lstring (128); iq: word; {command line, current index}
  pqq: ads of lstring (128);    {address CPM-type command line}
              cesxqq [extern]: word;   {segment val}
  c: char;  l: word;  iscomma: boolean;  i: word; {other stuff}

  FUNCTION parchr (ch: char): boolean;  {true iff CH found}
  BEGIN 
    parchr := (iq <= qq.len) AND (qq [iq] = ch);
    IF result (parchr) THEN iq := iq+1;
  END;
  
  FUNCTION upperc: char;  {return current char, in upper case}
  BEGIN
    upperc := qq[iq];
    IF result (upperc) >= 'a'
      THEN upperc := chr (ord (result (upperc)) - 32);
  END;

  PROCEDURE blanks;  {skip blanks and set any switches}
  BEGIN
    WHILE parchr (' ') DO {nothing};
    IF parchr ('/') THEN
    BEGIN
      IF (iq <= qq.len)
      AND THEN (ord (upperc) - 64) IN retype (sets, oldsw) 
      THEN
        BEGIN
          i := wrd (upperc) - 64;  iq := iq + 1;
          newsw[i DIV 8] := newsw[i DIV 8] OR setbit[i MOD 8];
          blanks;   {recurse for more}
        END
      ELSE iq := iq - 1;   {put "/" back on line to get error}
    END;
  END;

  FUNCTION parset (VAR dst: string;  CONST chs: setc): boolean;
  (* Move characters from qq to DST as long as they are in CHS
     Deletes from qq, blanks DST, returns true if any moved *)
  VAR i: word;   
  BEGIN
    fillc (adr dst, wrd (upper (dst)), ' ');  parset := false;
    FOR i := 1 TO wrd (upper (dst)) DO
      IF (iq > qq.len) OR ELSE NOT (qq [iq] IN chs) 
      THEN BREAK
      ELSE 
      BEGIN
        dst [i] := upperc;  parset := true;  iq := iq + 1;
      END;
  END;
  
  FUNCTION filenm (CONST prompt: string; VAR nam: filenam;
                   VAR fcb: cpmfn; defext: cpmex): boolean;
  (* Get a filename into the FCB, setting defaults as 
     appropriate;  return true iff a filename found *)
  VAR i: word;  p: adrmem;  defile: cpmnm;
  BEGIN
    blanks;
    IF iscomma THEN defile := prf.cfn ELSE defile := nuln;
    IF iq > qq.len THEN
    BEGIN
      ptyuqq (wrd (upper (prompt)), ads prompt);
      FOR i := 1 TO 8 DO 
        IF defile [i] <> ' ' THEN ptyuqq (1, ads defile [i]);
      ptyuqq (1, ads '.');  ptyuqq (3, ads defext);
      ptyuqq (3, ads ']: ');
      qq.len := gtyuqq (upper (qq), ads qq [1]);  iq := 1;
    END;
    fcb.cfp := '.';  
    IF (iq < qq.len) AND (qq [iq+1] = ':') 
      AND THEN parset (c, drset)
      THEN 
        BEGIN
          fcb.cfd[1] := c;  fcb.cfd[2] := ':';  iq := iq+1;
          defile := prf.cfn;   {default to source name now}
        END
      ELSE fcb.cfd := '  ';
    filenm := parset (fcb.cfn, idset);
    IF parchr (':') 
    THEN BEGIN  fcb.cfe := ':  ';  fcb.cfp := ' ';  END
    ELSE
    IF parchr ('.')
      THEN [eval (parset (fcb.cfe, idset));  defile := prf.cfn]
      ELSE fcb.cfe := defext;
    IF NOT result (filenm) THEN fcb.cfn := defile;
    blanks;
    nam.len := 0;  p := adr fcb;
    FOR i := 0 TO 13 DO IF p^[i] <> wrd (' ')
    THEN [nam.len := nam.len+1; nam[nam.len] := chr (p^[i])];
  END;

  FUNCTION conso (CONST fn: cpmnm): boolean;
  BEGIN
    conso := (fn = 'CON     ') OR (fn = 'USER    ');
  END;


BEGIN
  newsw := setsw (do 4 of 0);
  pqq.r := 128;   pqq.s := cesxqq; 
  FOR i := 0 TO pqq^.len+1 DO qq[i] := pqq^[i];  iq := 1;
  REPEAT
    iscomma := true;  prf.cfn := '        ';
    IF filenm (msprf, prffil, prf, dfprf)
    THEN
    BEGIN
      eval (parchr (','));
      eval (filenm (mshst, hstfil, hst, dfhst));
      iscomma := parchr (',');
      eval (filenm (msmap, mapfil, map, 'map'));
      blanks;  eval (parchr (';'));  blanks;
      IF hst.cfn <> nuln THEN newsw[3] := newsw[3] OR 8;
      IF map.cfn <> nuln THEN newsw[3] := newsw[3] OR 04;
      IF conso (map.cfn) THEN newsw[3] := newsw[3] OR 01;
      IF iq > qq.len THEN [oldsw := newsw;  return];
    END;
    ptyuqq (15, ads 'Line invalid: ''');  i := qq.len - iq + 1;
    IF i > 0 THEN ptyuqq (i, ads qq [iq]);
    ptyuqq (15, ads ''', start again.');  plyuqq;  iq := 256;
  UNTIL FALSE;
END;
END.
                                                     