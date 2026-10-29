MODULE Roler; (* Eula Oberon: Roler peste Cubicum FS, ca in Eula 7 (ideea lui Pion). Fiecare fisier mancat primeste
  un nod (x, y, z) din Z7^3 si frecventa nodului, f = 256 * (3/2)^x * 2^y * (7/4)^z. Cvinta (x) = domeniul codului,
  octava (y) = marimea, septima naturala (z) = sursa. Frecventa se calculeaza exact, cu numere intregi:
  f = 3^x * 7^z * 2^(8 + y - x - 2z). *)

  IMPORT Litere, Iesire, Memorie;

  CONST MaxRec = Memorie.MaxRec; MaxL = Memorie.MaxL;

  VAR domeniu, sursaN: ARRAY 7 OF ARRAY 40 OF CHAR;
    chei: ARRAY 7 OF ARRAY 24 OF ARRAY 12 OF CHAR; nchei: ARRAY 7 OF INTEGER;
    nodX*, nodY*, nodZ*: ARRAY MaxRec OF INTEGER;
    domL: ARRAY MaxL OF INTEGER; nlDom: INTEGER;
    cnt: ARRAY MaxRec OF ARRAY 7 OF INTEGER;
    calculatLa: INTEGER;

  PROCEDURE Chei(d: INTEGER; s: ARRAY OF CHAR);
    VAR i, j: INTEGER;
  BEGIN i := 0; nchei[d] := 0;
    WHILE s[i] # 0X DO
      j := 0;
      WHILE (s[i] # 0X) & (s[i] # " ") DO chei[d][nchei[d]][j] := s[i]; INC(i); INC(j) END ;
      chei[d][nchei[d]][j] := 0X; INC(nchei[d]);
      IF s[i] = " " THEN INC(i) END
    END
  END Chei;

  PROCEDURE Marime(octeti: INTEGER): INTEGER;
    VAR y: INTEGER;
  BEGIN y := 0;
    WHILE (y < 6) & (1024 * LSL(1, y + 1) <= octeti) DO INC(y) END ;
    RETURN y
  END Marime;

  PROCEDURE Sursa(r: INTEGER): INTEGER;
    VAR s: ARRAY 512 OF CHAR; z: INTEGER;
  BEGIN Memorie.SrcIn(r, s); Litere.MicS(s);
    IF Litere.Pos("raport", s, 0) >= 0 THEN z := 6
    ELSIF Litere.Incepe(s, "project oberon") THEN z := 1
    ELSIF (Litere.Pos("norebo", s, 0) >= 0) OR (Litere.Pos("pion", s, 0) >= 0) OR (Litere.Pos("jahbalon", s, 0) >= 0) OR (Litere.Pos("eula", s, 0) >= 0)
      OR (Litere.Pos("conversa", s, 0) >= 0) OR (Litere.Pos("învățat", s, 0) >= 0) OR (Litere.Pos("invatat", s, 0) >= 0) THEN z := 0
    ELSIF (Litere.Pos("/voc/", s, 0) >= 0) OR Litere.Incepe(s, "voc") THEN z := 2
    ELSIF Litere.Pos("obnc", s, 0) >= 0 THEN z := 3
    ELSIF (Litere.Pos("oberon-lab", s, 0) >= 0) OR (Litere.Pos("oberonlab", s, 0) >= 0) OR (Litere.Pos("/cub", s, 0) >= 0) OR (Litere.Pos("risc", s, 0) >= 0) THEN z := 4
    ELSE z := 5
    END ;
    RETURN z
  END Sursa;

  PROCEDURE Putere(b, e: INTEGER): INTEGER;
    VAR r: INTEGER;
  BEGIN r := 1; WHILE e > 0 DO r := r * b; DEC(e) END ;
    RETURN r
  END Putere;

  (* frecventa nodului, rotunjita (jumatatea in sus) *)
  PROCEDURE FrecInt(x, y, z: INTEGER): INTEGER;
    VAR n, e, r: INTEGER;
  BEGIN n := Putere(3, x) * Putere(7, z); e := 8 + y - x - 2 * z;
    IF e >= 0 THEN r := n * LSL(1, e) ELSE r := (n + LSL(1, -e - 1)) DIV LSL(1, -e) END ;
    RETURN r
  END FrecInt;

  PROCEDURE Frec(x, y, z: INTEGER): REAL;
    VAR n, e: INTEGER; f: REAL;
  BEGIN n := Putere(3, x) * Putere(7, z); e := 8 + y - x - 2 * z; f := FLT(n);
    WHILE e > 0 DO f := f * 2.0; DEC(e) END ;
    WHILE e < 0 DO f := f / 2.0; INC(e) END ;
    RETURN f
  END Frec;

  PROCEDURE D(a, b: INTEGER): INTEGER;
    VAR v: INTEGER;
  BEGIN v := (a - b) MOD 7; IF v > 3 THEN v := v - 7 END ;
    RETURN v
  END D;

  (* 0 unison, 1 octava, 2 cvinta, 3 virgula, 4 disonanta *)
  PROCEDURE Interval(r1, r2: INTEGER): INTEGER;
    VAR dx, dy, dz, k: INTEGER; fa, fb, q: REAL;
  BEGIN dx := D(nodX[r1], nodX[r2]); dy := D(nodY[r1], nodY[r2]); dz := D(nodZ[r1], nodZ[r2]);
    IF (dx = 0) & (dy = 0) & (dz = 0) THEN k := 0
    ELSIF (dx = 0) & (dz = 0) THEN k := 1
    ELSIF (ABS(dx) = 1) & (dz = 0) THEN k := 2
    ELSE
      fa := Frec(nodX[r1], nodY[r1], nodZ[r1]); fb := Frec(nodX[r2], nodY[r2], nodZ[r2]);
      IF fa > fb THEN q := fa / fb ELSE q := fb / fa END ;
      IF q - 1.0 <= 0.013 THEN k := 3 ELSE k := 4 END
    END ;
    RETURN k
  END Interval;

  PROCEDURE NodXYZ(x, y, z: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN
    Litere.Add(d, "nod ("); Litere.AddInt(d, x); Litere.AddCh(d, ","); Litere.AddInt(d, y); Litere.AddCh(d, ",");
    Litere.AddInt(d, z); Litere.Add(d, ") · "); Iesire.NrIn(d, FrecInt(x, y, z)); Litere.Add(d, " Hz · ");
    Litere.Add(d, domeniu[x]); Litere.Add(d, ", "); Litere.Add(d, sursaN[z])
  END NodXYZ;

  (* nodurile tuturor fisierelor; se reface cand a mancat ceva nou *)
  PROCEDURE Harta*;
    VAR i, d, k, r, u, j, best, bc: INTEGER; l: ARRAY 64 OF CHAR;
  BEGIN
    IF calculatLa # Memorie.nu THEN
      WHILE nlDom < Memorie.nl DO
        Memorie.LemaIn(nlDom, l); domL[nlDom] := -1; d := 0;
        WHILE (domL[nlDom] < 0) & (d < 7) DO
          k := 0;
          WHILE (domL[nlDom] < 0) & (k < nchei[d]) DO IF Litere.Incepe(l, chei[d][k]) THEN domL[nlDom] := d END ; INC(k) END ;
          INC(d)
        END ;
        INC(nlDom)
      END ;
      FOR r := 0 TO Memorie.nrec - 1 DO FOR d := 0 TO 6 DO cnt[r][d] := 0 END END ;
      FOR u := 0 TO Memorie.nu - 1 DO
        r := Memorie.uRec[u];
        FOR j := Memorie.uLemA[u] TO Memorie.uLemA[u] + Memorie.uLemN[u] - 1 DO
          i := Memorie.ulem[j];
          IF domL[i] >= 0 THEN INC(cnt[r][domL[i]]) END
        END
      END ;
      FOR r := 0 TO Memorie.nrec - 1 DO
        best := 6; bc := 0;
        FOR d := 0 TO 6 DO IF cnt[r][d] > bc THEN bc := cnt[r][d]; best := d END END ;
        nodX[r] := best; nodY[r] := Marime(Memorie.recN[r]); nodZ[r] := Sursa(r)
      END ;
      calculatLa := Memorie.nu
    END
  END Harta;

  PROCEDURE NodIn*(r: INTEGER; VAR d: ARRAY OF CHAR);     (* adauga „nod (x,y,z) · f Hz · domeniu, sursa” *)
  BEGIN Harta; NodXYZ(nodX[r], nodY[r], nodZ[r], d)
  END NodIn;

  PROCEDURE Nume(r: INTEGER);
    VAR s, m: ARRAY 600 OF CHAR; n: INTEGER;
  BEGIN Memorie.SrcIn(r, s); n := Litere.Len(s);
    IF n > 50 THEN m := "…"; Litere.Add(m, ""); Litere.Sub(s, n - 49, n, s); Litere.Add(m, s); s := m END ;
    Memorie.ModIn(r, m);
    IF m[0] # 0X THEN Iesire.S(m); Iesire.S(" ("); Iesire.S(s); Iesire.S(")") ELSE Iesire.S(s) END
  END Nume;

  PROCEDURE Striga*(f: INTEGER);
    VAR x, y, z, k, noduri, cate: INTEGER; g, q, ff: REAL; d: ARRAY 300 OF CHAR; prim: BOOLEAN;
  BEGIN Harta; noduri := 0; prim := TRUE; ff := FLT(f);
    FOR x := 0 TO 6 DO FOR y := 0 TO 6 DO FOR z := 0 TO 6 DO
      g := Frec(x, y, z);
      IF ff > g THEN q := ff / g ELSE q := g / ff END ;
      IF q - 1.0 <= 0.001 THEN
        INC(noduri);
        IF ~prim THEN Iesire.C(0AX) END ; prim := FALSE;
        d := ""; NodXYZ(x, y, z, d);
        Iesire.S("Răspunde "); Iesire.S(d); Iesire.S(": ");
        cate := 0;
        FOR k := 0 TO Memorie.nrec - 1 DO IF (nodX[k] = x) & (nodY[k] = y) & (nodZ[k] = z) & (Memorie.recN[k] > 0) THEN INC(cate) END END ;
        Iesire.Int(cate); IF cate = 1 THEN Iesire.S(" fișier") ELSE Iesire.S(" fișiere") END ;
        cate := 0;
        FOR k := 0 TO Memorie.nrec - 1 DO
          IF (nodX[k] = x) & (nodY[k] = y) & (nodZ[k] = z) & (Memorie.recN[k] > 0) THEN
            IF cate < 7 THEN IF cate = 0 THEN Iesire.S(" — ") ELSE Iesire.S("; ") END ; Nume(k) END ;
            INC(cate)
          END
        END ;
        IF cate > 7 THEN Iesire.S(" …") END
      END
    END END END ;
    IF noduri = 0 THEN
      Iesire.S("Frecvența "); Iesire.Int(f); Iesire.S(".00 Hz e străină de rețea: niciun nod nu răspunde (ca 440 Hz în Roler).")
    END
  END Striga;

  PROCEDURE SunaCu*(r: INTEGER);
    VAR c, k, n, shown: INTEGER; d: ARRAY 300 OF CHAR; nume: ARRAY 3 OF ARRAY 12 OF CHAR;
  BEGIN Harta;
    IF (r < 0) OR (r >= Memorie.nrec) THEN Iesire.S("Întâi întreabă-mă ceva; apoi îți spun ce sună cu fișierul din care am răspuns.")
    ELSE
      nume[0] := "unison"; nume[1] := "octavă"; nume[2] := "cvintă";
      Iesire.S("Fișierul "); Nume(r); d := ""; NodIn(r, d); Iesire.S(" stă în "); Iesire.S(d); Iesire.S(".");
      FOR c := 0 TO 2 DO
        n := 0;
        FOR k := 0 TO Memorie.nrec - 1 DO IF (k # r) & (Memorie.recN[k] > 0) & (Interval(r, k) = c) THEN INC(n) END END ;
        Iesire.C(0AX); Iesire.S(nume[c]); Iesire.S(": "); Iesire.Int(n);
        shown := 0;
        FOR k := 0 TO Memorie.nrec - 1 DO
          IF (k # r) & (Memorie.recN[k] > 0) & (Interval(r, k) = c) & (shown < 5) THEN
            IF shown = 0 THEN Iesire.S(" — ") ELSE Iesire.S("; ") END ; Nume(k); INC(shown)
          END
        END ;
        IF n > 5 THEN Iesire.S(" …") END
      END
    END
  END SunaCu;

  PROCEDURE Rezumat*;
    VAR c: ARRAY 3 OF ARRAY 7 OF INTEGER; k, a, n, d: INTEGER;
  BEGIN Harta; n := 0;
    FOR a := 0 TO 2 DO FOR d := 0 TO 6 DO c[a][d] := 0 END END ;
    FOR k := 0 TO Memorie.nrec - 1 DO
      IF Memorie.recN[k] > 0 THEN INC(n); INC(c[0][nodX[k]]); INC(c[1][nodY[k]]); INC(c[2][nodZ[k]]) END
    END ;
    Iesire.S("Am "); Iesire.Int(n); Iesire.S(" fișiere așezate în cub. Cvinta (domeniul): ");
    FOR d := 0 TO 6 DO IF d > 0 THEN Iesire.S(", ") END ; Iesire.S(domeniu[d]); Iesire.S(" "); Iesire.Int(c[0][d]) END ;
    Iesire.S("."); Iesire.C(0AX); Iesire.S("Octava (mărimea, de la sub 2 KB la peste 64 KB): ");
    FOR d := 0 TO 6 DO IF d > 0 THEN Iesire.S(", ") END ; Iesire.Int(c[1][d]) END ;
    Iesire.S("."); Iesire.C(0AX); Iesire.S("Septima (sursa): ");
    FOR d := 0 TO 6 DO IF d > 0 THEN Iesire.S(", ") END ; Iesire.S(sursaN[d]); Iesire.S(" "); Iesire.Int(c[2][d]) END ;
    Iesire.S(".")
  END Rezumat;

BEGIN calculatLa := -1; nlDom := 0;
  domeniu[0] := "sistem și memorie"; domeniu[1] := "fișiere"; domeniu[2] := "text"; domeniu[3] := "ecran și grafică";
  domeniu[4] := "matematică"; domeniu[5] := "compilator"; domeniu[6] := "altele";
  sursaN[0] := "scrierile lui Pion"; sursaN[1] := "Project Oberon 2013"; sursaN[2] := "voc (Oberon-2)"; sursaN[3] := "OBNC";
  sursaN[4] := "Oberon Lab / Cub"; sursaN[5] := "fișier importat"; sursaN[6] := "raportul lui Wirth";
  Chei(0, "kernel heap system modules adr trap platform signal alloc memory gc collect sector reboot task process thread stack");
  Chei(1, "file rider dir disk path filename fs directory rename purge register old length");
  Chei(2, "text string str char scanner writer reader buf piece ascii conv line word append insert delete elem");
  Chei(3, "display viewer frame font pattern dot block replconst mouse cursor graphic curve rect draw color pixel window screen menu track");
  Chei(4, "math sqrt sin cos exp arctan float complex random entier real matrix vector number pow round");
  Chei(5, "compil pars symbol sym emit fixup opcode ors orp org orb obj item scope ident token grammar code");
  Chei(6, "net rs232 scc pio input keyboard socket packet send receive port serial clock time")
END Roler.
