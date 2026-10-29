MODULE BusolaApp;  (* busola ca aplicatie Android. O faci cu:  apk BusolaApp.Mod Busola *)
  IMPORT Math, Strings, Ecran, Senzor;

  VAR ok: BOOLEAN;
    arata: REAL;                                   (* unghiul desenat, netezit ca acul sa nu tremure *)
    violet, violet2, aur, stins, rosu: INTEGER;    (* culorile *)
    nume: ARRAY 8 OF ARRAY 4 OF CHAR;

  (* punctul de pe cercul (cx, cy, r) la unghiul g (grade; 0 = sus, in sensul acelor) *)
  PROCEDURE P(cx, cy: INTEGER; r, g: REAL; VAR x, y: INTEGER);
    VAR t: REAL;
  BEGIN
    t := g * Math.pi / 180.0;
    x := cx + FLOOR(r * Math.sin(t) + 0.5);
    y := cy - FLOOR(r * Math.cos(t) + 0.5)
  END P;

  PROCEDURE Netezeste(a: INTEGER);
    VAR d: REAL;
  BEGIN
    d := FLT(a) - arata;
    WHILE d > 180.0 DO d := d - 360.0 END;
    WHILE d < -180.0 DO d := d + 360.0 END;
    arata := arata + d * 0.15;
    IF arata < 0.0 THEN arata := arata + 360.0 ELSIF arata >= 360.0 THEN arata := arata - 360.0 END
  END Netezeste;

  PROCEDURE Deseneaza*;   (* o cheama aplicatia la fiecare cadru *)
    VAR w, h, cx, cy, r, i, u, x0, y0, x1, y1, x2, y2, d, a: INTEGER; s: ARRAY 32 OF CHAR;
  BEGIN
    w := Ecran.Latime(); h := Ecran.Inaltime();
    cx := w DIV 2; cy := h * 9 DIV 20;
    IF w < h THEN r := w * 2 DIV 5 ELSE r := h * 2 DIV 5 END;
    d := Ecran.Densitate() DIV 100 + 1;
    Ecran.Fond(violet);
    a := Senzor.Azimut();
    IF ~ok THEN
      Ecran.Culoare(aur); Ecran.Text(cx, cy, 16 * d, "Telefonul n-are busola")
    ELSE
      IF a >= 0 THEN Netezeste(a) END;
      Ecran.Culoare(violet2); Ecran.Disc(cx, cy, r + 6 * d);
      Ecran.Culoare(stins); Ecran.Grosime(d); Ecran.Cerc(cx, cy, r + 6 * d);
      (* gradatiile: la 10 grade, mai lungi la 30; ele se rotesc cu telefonul *)
      FOR i := 0 TO 35 DO
        u := i * 10;
        IF u MOD 30 = 0 THEN Ecran.Grosime(d + 1); P(cx, cy, FLT(r) * 0.86, FLT(u) - arata, x0, y0)
        ELSE Ecran.Grosime(d); P(cx, cy, FLT(r) * 0.92, FLT(u) - arata, x0, y0)
        END;
        P(cx, cy, FLT(r), FLT(u) - arata, x1, y1);
        Ecran.Linie(x0, y0, x1, y1)
      END;
      (* punctele cardinale *)
      FOR i := 0 TO 3 DO
        P(cx, cy, FLT(r) * 0.70, FLT(i * 90) - arata, x0, y0);
        IF i = 0 THEN Ecran.Culoare(rosu) ELSE Ecran.Culoare(aur) END;
        Ecran.Text(x0, y0 + 8 * d, 22 * d, nume[i * 2])
      END;
      (* acul: rosu spre nord, auriu stins spre sud *)
      P(cx, cy, FLT(r) * 0.52, -arata, x0, y0);
      P(cx, cy, FLT(r) * 0.07, 90.0 - arata, x1, y1);
      P(cx, cy, FLT(r) * 0.07, -90.0 - arata, x2, y2);
      Ecran.Culoare(rosu); Ecran.Triunghi(x0, y0, x1, y1, x2, y2);
      P(cx, cy, FLT(r) * 0.52, 180.0 - arata, x0, y0);
      Ecran.Culoare(stins); Ecran.Triunghi(x0, y0, x1, y1, x2, y2);
      Ecran.Culoare(aur); Ecran.Disc(cx, cy, 5 * d);
      (* reperul telefonului, sus *)
      Ecran.Culoare(aur);
      Ecran.Triunghi(cx, cy - r - 10 * d, cx - 9 * d, cy - r - 26 * d, cx + 9 * d, cy - r - 26 * d);
      (* textul de jos *)
      u := FLOOR(arata + 0.5) MOD 360;
      s := ""; Strings.AppendInt(u, 0, s); Strings.Append(" grade  ", s);
      Strings.Append(nume[(u + 22) MOD 360 DIV 45], s);
      Ecran.Text(cx, cy + r + 60 * d, 26 * d, s);
      Ecran.Culoare(stins);
      IF a < 0 THEN Ecran.Text(cx, cy + r + 95 * d, 14 * d, "astept senzorul...")
      ELSE Ecran.Text(cx, cy + r + 95 * d, 14 * d, "facuta cu Eula Oberon")
      END
    END
  END Deseneaza;

BEGIN
  violet := Ecran.RGB(22, 4, 42); violet2 := Ecran.RGB(36, 10, 66);
  aur := Ecran.RGB(201, 168, 94); stins := Ecran.RGB(140, 116, 70); rosu := Ecran.RGB(214, 64, 52);
  nume[0] := "N"; nume[1] := "NE"; nume[2] := "E"; nume[3] := "SE";
  nume[4] := "S"; nume[5] := "SV"; nume[6] := "V"; nume[7] := "NV";
  arata := 0.0;
  ok := Senzor.Porneste()
END BusolaApp.
