MODULE Nivela;  (* nivela cu bula, ca aplicatie Android. O faci cu:  apk Nivela.Mod Nivela
   Culcat pe masa: bula rotunda (doua directii). In picioare, pe o muchie: bula in tub (o directie).
   Atinge ecranul pe o suprafata dreapta ca s-o calibrezi; inca o atingere anuleaza calibrarea. *)
  IMPORT Math, Strings, Ecran, Senzor;

  CONST Grad = 57.29578;   (* 180 / pi *)

  VAR ok, calibrat, inainte: BOOLEAN;
    fx, fy, fz: REAL;            (* gravitatia, netezita (miimi de g) *)
    zx, zy, zd: REAL;            (* zero-ul calibrarii *)
    violet, violet2, aur, stins, verde, sticla: INTEGER;
    rx, ry, rd: REAL;            (* ultimele unghiuri necalibrate (pentru atingere) *)
    plat: BOOLEAN;

  (* v cu o zecimala, fara "-0.0" *)
  PROCEDURE Zecimi(v: REAL; VAR s: ARRAY OF CHAR);
    VAR t: INTEGER;
  BEGIN
    t := FLOOR(ABS(v) * 10.0 + 0.5);
    IF (v < 0.0) & (t > 0) THEN Strings.Append("-", s) END;
    Strings.AppendInt(t DIV 10, 0, s); Strings.Append(".", s); Strings.AppendInt(t MOD 10, 0, s)
  END Zecimi;

  PROCEDURE Limita(v, m: REAL): REAL;
  BEGIN
    IF v > m THEN v := m ELSIF v < -m THEN v := -m END
    RETURN v
  END Limita;

  (* culcat pe masa: bula rotunda; ax spre dreapta, ay spre sus, in grade *)
  PROCEDURE Rotunda(cx, cy, r, d: INTEGER; ax, ay: REAL);
    VAR bx, by, i: INTEGER; dist, k: REAL; s: ARRAY 48 OF CHAR;
  BEGIN
    Ecran.Culoare(violet2); Ecran.Disc(cx, cy, r);
    Ecran.Culoare(stins); Ecran.Grosime(d);
    Ecran.Cerc(cx, cy, r); Ecran.Cerc(cx, cy, r * 2 DIV 3); Ecran.Cerc(cx, cy, r DIV 3);
    Ecran.Linie(cx - r, cy, cx + r, cy); Ecran.Linie(cx, cy - r, cx, cy + r);
    (* 10 grade = marginea cercului *)
    dist := Math.sqrt(ax * ax + ay * ay);
    k := FLT(r) / 10.0;
    IF dist > 10.0 THEN k := k * 10.0 / dist END;
    bx := cx + FLOOR(ax * k + 0.5); by := cy - FLOOR(ay * k + 0.5);
    i := r DIV 7;
    IF dist < 0.3 THEN Ecran.Culoare(verde) ELSE Ecran.Culoare(sticla) END;
    Ecran.Disc(bx, by, i);
    Ecran.Culoare(aur); Ecran.Grosime(d * 2); Ecran.Cerc(bx, by, i);
    (* cifrele *)
    IF dist < 0.3 THEN Ecran.Culoare(verde) ELSE Ecran.Culoare(aur) END;
    s := ""; Zecimi(dist, s); Strings.Append(" grade", s);
    Ecran.Text(cx, cy + r + 70 * d, 34 * d, s);
    Ecran.Culoare(stins);
    s := "stanga-dreapta "; Zecimi(ax, s); Strings.Append("   sus-jos ", s); Zecimi(ay, s);
    Ecran.Text(cx, cy + r + 105 * d, 15 * d, s)
  END Rotunda;

  (* in picioare: bula in tub; tub de-a lungul lui (tx, ty), dev in grade *)
  PROCEDURE Tub(cx, cy, l, d: INTEGER; tx, ty, dev: REAL);
    VAR x0, y0, x1, y1, bx, by, g: INTEGER; u: REAL; s: ARRAY 48 OF CHAR;
  BEGIN
    x0 := cx - FLOOR(tx * FLT(l) / 2.0); y0 := cy - FLOOR(ty * FLT(l) / 2.0);
    x1 := cx + FLOOR(tx * FLT(l) / 2.0); y1 := cy + FLOOR(ty * FLT(l) / 2.0);
    g := 46 * d;
    Ecran.Culoare(stins); Ecran.Grosime(g + 4 * d); Ecran.Linie(x0, y0, x1, y1);
    Ecran.Disc(x0, y0, (g + 4 * d) DIV 2); Ecran.Disc(x1, y1, (g + 4 * d) DIV 2);
    Ecran.Culoare(violet2); Ecran.Grosime(g); Ecran.Linie(x0, y0, x1, y1);
    Ecran.Disc(x0, y0, g DIV 2); Ecran.Disc(x1, y1, g DIV 2);
    (* reperele de la mijloc, perpendiculare pe tub *)
    Ecran.Culoare(aur); Ecran.Grosime(d * 2);
    u := FLT(g) * 0.9;
    Ecran.Linie(cx - FLOOR(tx * u / 2.0) - FLOOR(ty * u / 2.0), cy - FLOOR(ty * u / 2.0) + FLOOR(tx * u / 2.0),
      cx - FLOOR(tx * u / 2.0) + FLOOR(ty * u / 2.0), cy - FLOOR(ty * u / 2.0) - FLOOR(tx * u / 2.0));
    Ecran.Linie(cx + FLOOR(tx * u / 2.0) - FLOOR(ty * u / 2.0), cy + FLOOR(ty * u / 2.0) + FLOOR(tx * u / 2.0),
      cx + FLOOR(tx * u / 2.0) + FLOOR(ty * u / 2.0), cy + FLOOR(ty * u / 2.0) - FLOOR(tx * u / 2.0));
    (* bula: 5 grade = capatul tubului *)
    u := Limita(dev, 5.0) / 5.0 * (FLT(l) / 2.0 - FLT(g) * 0.6);
    bx := cx + FLOOR(tx * u + 0.5); by := cy + FLOOR(ty * u + 0.5);
    IF ABS(dev) < 0.3 THEN Ecran.Culoare(verde) ELSE Ecran.Culoare(sticla) END;
    Ecran.Disc(bx, by, g * 2 DIV 5);
    Ecran.Culoare(aur); Ecran.Grosime(d * 2); Ecran.Cerc(bx, by, g * 2 DIV 5);
    IF ABS(dev) < 0.3 THEN Ecran.Culoare(verde) ELSE Ecran.Culoare(aur) END;
    s := ""; Zecimi(ABS(dev), s); Strings.Append(" grade", s);
    Ecran.Text(cx, Ecran.Inaltime() * 4 DIV 5, 34 * d, s)
  END Tub;

  PROCEDURE Deseneaza*;   (* o cheama aplicatia la fiecare cadru *)
    VAR w, h, cx, cy, r, d, q: INTEGER; n, m, a: REAL;
  BEGIN
    w := Ecran.Latime(); h := Ecran.Inaltime();
    cx := w DIV 2; cy := h * 2 DIV 5;
    IF w < h THEN r := w * 2 DIV 5 ELSE r := h * 2 DIV 5 END;
    d := Ecran.Densitate() DIV 100 + 1;
    Ecran.Fond(violet);
    Ecran.Culoare(aur); Ecran.Text(cx, 60 * d, 22 * d, "NIVELA");
    IF ~ok THEN
      Ecran.Text(cx, cy, 16 * d, "Telefonul n-are senzor de gravitatie")
    ELSE
      fx := fx + (FLT(Senzor.GX()) - fx) * 0.2;
      fy := fy + (FLT(Senzor.GY()) - fy) * 0.2;
      fz := fz + (FLT(Senzor.GZ()) - fz) * 0.2;
      n := Math.sqrt(fx * fx + fy * fy + fz * fz);
      m := Math.sqrt(fx * fx + fy * fy);
      IF n < 100.0 THEN
        Ecran.Text(cx, cy, 16 * d, "astept senzorul...")
      ELSE
        plat := ABS(fz) > n * 0.7;    (* mai putin de ~45 de grade fata de masa *)
        IF plat THEN
          rx := Math.arctan2(fx, ABS(fz)) * Grad; ry := Math.arctan2(fy, ABS(fz)) * Grad;
          Rotunda(cx, cy, r, d, rx - zx, ry - zy)
        ELSE
          a := Math.arctan2(fx, fy) * Grad;          (* 0 = in picioare, +-90 = culcat pe o parte *)
          q := FLOOR((a + 45.0) / 90.0);
          rd := a - FLT(q) * 90.0;
          Tub(cx, cy, w * 4 DIV 5, d, fy / m, fx / m, rd - zd)
        END
      END;
      Ecran.Culoare(stins);
      IF calibrat THEN Ecran.Text(cx, h - 40 * d, 14 * d, "calibrata - atinge ca s-o anulezi")
      ELSE Ecran.Text(cx, h - 40 * d, 14 * d, "pe o suprafata dreapta, atinge ca s-o calibrezi")
      END
    END
  END Deseneaza;

  PROCEDURE Atinge*;   (* la apasare (nu la miscare sau ridicare): calibreaza sau anuleaza *)
    VAR acum: BOOLEAN;
  BEGIN
    acum := Ecran.Apasat();
    IF acum & ~inainte THEN
      IF calibrat THEN zx := 0.0; zy := 0.0; zd := 0.0; calibrat := FALSE
      ELSIF plat THEN zx := rx; zy := ry; calibrat := TRUE
      ELSE zd := rd; calibrat := TRUE
      END
    END;
    inainte := acum
  END Atinge;

BEGIN
  violet := Ecran.RGB(22, 4, 42); violet2 := Ecran.RGB(36, 10, 66);
  aur := Ecran.RGB(201, 168, 94); stins := Ecran.RGB(140, 116, 70);
  verde := Ecran.RGB(92, 214, 130); sticla := Ecran.RGB(214, 196, 120);
  fx := 0.0; fy := 0.0; fz := 1000.0; zx := 0.0; zy := 0.0; zd := 0.0;
  calibrat := FALSE; inainte := FALSE; plat := TRUE;
  ok := Senzor.PornesteGravitatia()
END Nivela.
