MODULE Disc; (* Eula Oberon: scris si citit pe disc, octet cu octet, printr-un tampon de 64 KB *)
  IMPORT Files;

  CONST B = 65536;

  VAR f: Files.File; buf: ARRAY B OF BYTE; bp, bn: INTEGER; scriu: BOOLEAN;
    ok*: BOOLEAN;

  PROCEDURE Scrie*(nume: ARRAY OF CHAR): BOOLEAN;
  BEGIN f := Files.Create(nume); bp := 0; scriu := TRUE; ok := f # NIL;
    RETURN ok
  END Scrie;

  PROCEDURE Citeste*(nume: ARRAY OF CHAR): BOOLEAN;
  BEGIN
    IF Files.Exists(nume) THEN f := Files.Open(nume) ELSE f := NIL END ;
    bp := 0; bn := 0; scriu := FALSE; ok := f # NIL;
    RETURN ok
  END Citeste;

  PROCEDURE Goleste;
  BEGIN
    IF bp > 0 THEN Files.WriteNBytes(f, buf, bp); bp := 0 END
  END Goleste;

  PROCEDURE Inchide*;
  BEGIN
    IF f # NIL THEN
      IF scriu THEN Goleste; ok := ok & (Files.Status(f) = Files.OK) END ;
      Files.Close(f); f := NIL
    END
  END Inchide;

  PROCEDURE Pune*(x: INTEGER);
  BEGIN
    IF bp = B THEN Goleste END ;
    buf[bp] := x MOD 256; INC(bp)
  END Pune;

  PROCEDURE PuneInt*(x: INTEGER);
  BEGIN Pune(x MOD 256); Pune(ASR(x, 8) MOD 256); Pune(ASR(x, 16) MOD 256); Pune(ASR(x, 24) MOD 256)
  END PuneInt;

  PROCEDURE PuneCh*(c: CHAR);
  BEGIN Pune(ORD(c) MOD 256); Pune(ORD(c) DIV 256)
  END PuneCh;

  PROCEDURE PuneBool*(b: BOOLEAN);
  BEGIN IF b THEN Pune(1) ELSE Pune(0) END
  END PuneBool;

  PROCEDURE PuneSir*(s: ARRAY OF CHAR);
    VAR i, n: INTEGER;
  BEGIN n := 0;
    WHILE (n < LEN(s)) & (s[n] # 0X) DO INC(n) END ;
    PuneInt(n); i := 0;
    WHILE i < n DO PuneCh(s[i]); INC(i) END
  END PuneSir;

  PROCEDURE Ia*(): INTEGER;
    VAR x: INTEGER;
  BEGIN
    IF bp >= bn THEN
      bp := 0; bn := 0;
      IF ok THEN Files.ReadBytes(f, buf, bn) END ;
      IF bn <= 0 THEN bn := 0; ok := FALSE END
    END ;
    IF bp < bn THEN x := buf[bp]; INC(bp) ELSE x := 0 END ;
    RETURN x
  END Ia;

  PROCEDURE IaInt*(): INTEGER;
    VAR b0, b1, b2, b3: INTEGER;
  BEGIN b0 := Ia(); b1 := Ia(); b2 := Ia(); b3 := Ia();
    RETURN b0 + LSL(b1, 8) + LSL(b2, 16) + LSL(b3, 24)
  END IaInt;

  PROCEDURE IaCh*(): CHAR;
    VAR a, b: INTEGER;
  BEGIN a := Ia(); b := Ia();
    RETURN CHR(a + b * 256)
  END IaCh;

  PROCEDURE IaBool*(): BOOLEAN;
  BEGIN RETURN Ia() # 0
  END IaBool;

  PROCEDURE IaSir*(VAR s: ARRAY OF CHAR);
    VAR i, n: INTEGER; c: CHAR;
  BEGIN n := IaInt(); i := 0;
    WHILE ok & (i < n) DO
      c := IaCh();
      IF i < LEN(s) - 1 THEN s[i] := c END ;
      INC(i)
    END ;
    IF (n >= 0) & (n < LEN(s)) THEN s[n] := 0X ELSIF n < 0 THEN s[0] := 0X ELSE s[LEN(s) - 1] := 0X END
  END IaSir;

  PROCEDURE Sterge*(nume: ARRAY OF CHAR);
    VAR r: INTEGER;
  BEGIN
    IF Files.Exists(nume) THEN r := Files.Delete(nume) END
  END Sterge;

  PROCEDURE Redenumeste*(de, la: ARRAY OF CHAR): BOOLEAN;
  BEGIN Sterge(la);
    RETURN Files.Rename(de, la) = Files.OK
  END Redenumeste;

BEGIN f := NIL; ok := FALSE
END Disc.
