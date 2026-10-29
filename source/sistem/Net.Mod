MODULE Net;  (* internetul: descarca URL [fisier] *)
  IMPORT Out, Param, Retea;

  CONST N = 2048;

  (* numele fisierului din URL: ce e dupa ultimul / (fara ?…) *)
  PROCEDURE NumeDin(url: ARRAY OF CHAR; VAR nume: ARRAY OF CHAR);
    VAR i, a, z, k: INTEGER;
  BEGIN
    i := 0; a := 0; z := 0;
    WHILE (i < LEN(url)) & (url[i] # 0X) & (url[i] # "?") & (url[i] # "#") DO
      IF url[i] = "/" THEN a := i + 1 END;
      INC(i)
    END;
    z := i; k := 0;
    WHILE (a < z) & (k < LEN(nume) - 1) DO nume[k] := url[a]; INC(k); INC(a) END;
    nume[k] := 0X;
    IF k = 0 THEN nume := "descarcat" END
  END NumeDin;

  PROCEDURE Descarca*;   (* descarca URL [fisier] *)
    VAR url, fis: ARRAY N OF CHAR; e: ARRAY 256 OF CHAR; n: INTEGER;
  BEGIN
    IF Param.Nr() = 0 THEN Out.String("folosire: descarca https://... [Fisier]"); Out.Ln
    ELSE
      Param.Str(0, url);
      IF Param.Nr() > 1 THEN Param.Str(1, fis) ELSE NumeDin(url, fis) END;
      Out.String("descarc "); Out.String(fis); Out.String(" ..."); Out.Ln;
      n := Retea.Descarca(url, fis);
      IF n >= 0 THEN Out.String("gata: "); Out.Int(n, 0); Out.String(" octeti in "); Out.String(fis)
      ELSE Retea.Eroare(e); Out.String("n-a mers: "); Out.String(e)
      END;
      Out.Ln
    END
  END Descarca;

END Net.
