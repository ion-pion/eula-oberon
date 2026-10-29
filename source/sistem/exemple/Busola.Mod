MODULE Busola;  (* o busola in terminal. Porneste-o cu:  Busola.Mod  sau  Busola.Mod 60  (cate secunde) *)
  IMPORT Out, Math, Strings, Param, Senzor, Nucleu;

  CONST R = 9; C = 21;          (* roza: 9 randuri x 21 coloane; centrul in (4, 10) *)
    L = 41;                     (* banda de jos: 41 de caractere, unul la 5 grade *)

  VAR nume: ARRAY 8 OF ARRAY 4 OF CHAR;
    roza: ARRAY R OF ARRAY C + 1 OF CHAR;

  PROCEDURE Esc(s: ARRAY OF CHAR);
  BEGIN Out.Char(1BX); Out.String(s)
  END Esc;

  (* pune caracterul c pe roza, la unghiul t (grade, 0 = sus, in sensul acelor) si raza r (0..1) *)
  PROCEDURE Pune(t: INTEGER; r: REAL; c: CHAR);
    VAR x: REAL; rand, col: INTEGER;
  BEGIN
    x := FLT(t) * Math.pi / 180.0;
    rand := 4 - FLOOR(4.0 * r * Math.cos(x) + 0.5);
    col := 10 + FLOOR(9.0 * r * Math.sin(x) + 0.5);
    IF (rand >= 0) & (rand < R) & (col >= 0) & (col < C) THEN roza[rand][col] := c END
  END Pune;

  PROCEDURE Roza(a: INTEGER);   (* a = incotro arata telefonul; nordul e la -a pe ecran *)
    VAR i, j: INTEGER;
  BEGIN
    FOR i := 0 TO R - 1 DO
      FOR j := 0 TO C - 1 DO roza[i][j] := " " END;
      roza[i][C] := 0X
    END;
    FOR i := 0 TO 15 DO Pune(i * 360 DIV 16, 1.0, ".") END;
    FOR i := 1 TO 3 DO Pune(-a, FLT(i) / 4.0, "*"); Pune(180 - a, FLT(i) / 4.0, ":") END;
    roza[4][10] := "o";
    Pune(-a, 1.0, "N"); Pune(90 - a, 1.0, "E"); Pune(180 - a, 1.0, "S"); Pune(270 - a, 1.0, "V");
    Pune(0, 1.0, "^");            (* varful telefonului *)
    FOR i := 0 TO R - 1 DO Out.String("   "); Out.String(roza[i]); Esc("[K"); Out.Ln END
  END Roza;

  PROCEDURE Banda(a: INTEGER);
    VAR c, u, b: INTEGER;
  BEGIN
    b := (a + 2) DIV 5 * 5;       (* rotunjit la 5 grade, ca semnele sa stea pe loc *)
    FOR c := -(L DIV 2) TO L DIV 2 DO
      u := (b + c * 5 + 720) MOD 360;
      IF u = 0 THEN Out.Char("N") ELSIF u = 90 THEN Out.Char("E")
      ELSIF u = 180 THEN Out.Char("S") ELSIF u = 270 THEN Out.Char("V")
      ELSIF u MOD 45 = 0 THEN Out.Char("+") ELSIF u MOD 15 = 0 THEN Out.Char("|")
      ELSE Out.Char(".")
      END
    END;
    Esc("[K"); Out.Ln;
    FOR c := 1 TO L DIV 2 DO Out.Char(" ") END; Out.Char("^"); Esc("[K"); Out.Ln
  END Banda;

  PROCEDURE Arata(a: INTEGER);
    VAR d: ARRAY 4 OF CHAR;
  BEGIN
    Esc("[H");
    Out.String("BUSOLA  (telefonul tinut culcat, varful = ^)"); Esc("[K"); Out.Ln; Out.Ln;
    IF a < 0 THEN Out.String("astept senzorul..."); Esc("[K"); Out.Ln
    ELSE
      Roza(a); Out.Ln;
      Banda(a); Out.Ln;
      Strings.Copy(nume[(a + 22) MOD 360 DIV 45], d);
      Out.String("Azimut: "); Out.Int(a, 3); Out.String(" grade  "); Out.String(d); Esc("[K"); Out.Ln
    END;
    Esc("[J")
  END Arata;

  PROCEDURE Porneste;
    VAR sec, t0: INTEGER;
  BEGIN
    IF Param.EInt(1) THEN sec := Param.Int(1) ELSE sec := 20 END;
    IF ~Senzor.Porneste() THEN
      Out.String("Telefonul n-are busola (senzor magnetic)."); Out.Ln
    ELSE
      Esc("[2J");
      t0 := Nucleu.Timp();
      WHILE (Nucleu.Timp() - t0 < sec * 1000) & ~Nucleu.Oprit() DO
        Arata(Senzor.Azimut());
        Nucleu.Asteapta(120)
      END;
      Senzor.Opreste;
      IF Nucleu.Oprit() THEN Out.String("(oprita cu Ctrl+C)")
      ELSE Out.String("(gata dupa "); Out.Int(sec, 0); Out.String(" secunde; Busola.Mod 60 = un minut)")
      END;
      Out.Ln
    END
  END Porneste;

BEGIN
  nume[0] := "N"; nume[1] := "NE"; nume[2] := "E"; nume[3] := "SE";
  nume[4] := "S"; nume[5] := "SV"; nume[6] := "V"; nume[7] := "NV";
  Porneste
END Busola.
