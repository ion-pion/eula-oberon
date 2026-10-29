MODULE Nephilim;

CONST
  Inactiv*   = 0;
  Corpuscul* = 1;
  Unda*      = 2;
  SuperPos*  = 3;

TYPE
  Node* = RECORD
    state* : INTEGER;
    freq*  : REAL;
    r*,g*,b* : INTEGER
  END;
  Cube* = ARRAY 7, 7, 7 OF Node;

PROCEDURE Power(base: REAL; exp: INTEGER): REAL;
  VAR result: REAL; i: INTEGER;
BEGIN
  result := 1.0;
  FOR i := 1 TO exp DO
    result := result * base
  END;
  RETURN result
END Power;

PROCEDURE Freq*(x, y, z: INTEGER): REAL;
BEGIN
  RETURN 256.0 * Power(1.5, x) * Power(2.0, y) * Power(1.75, z)
END Freq;

PROCEDURE Init*(VAR c: Cube);
VAR x,y,z: INTEGER;
BEGIN
  FOR x := 0 TO 6 DO
    FOR y := 0 TO 6 DO
      FOR z := 0 TO 6 DO
        c[x][y][z].state := Inactiv;
        c[x][y][z].freq  := Freq(x, y, z);
        c[x][y][z].r := x * 42;
        c[x][y][z].g := y * 42;
        c[x][y][z].b := z * 42
      END
    END
  END
END Init;

PROCEDURE SetState*(VAR c: Cube; x,y,z,s: INTEGER);
BEGIN c[x][y][z].state := s END SetState;

PROCEDURE GetState*(c: Cube; x,y,z: INTEGER): INTEGER;
BEGIN RETURN c[x][y][z].state END GetState;

END Nephilim.

MODULE CorziZ7;  (* instrumentele Nephilim din SonicZ7.Mod si MeetZ7.Mod (Pion), mutate in Eula: in loc de pipe
   catre play, scriu esantioanele intr-un buffer pe care il canta Sunet.Reda. Coarda ciupita e Karplus-Strong. *)
  IMPORT Math, Nephilim;

  CONST Scurt* = 1597; Mediu* = 17711; Lung* = 46368;   (* durate Fibonacci, in esantioane la 44100 Hz *)

  VAR noiseSeed: REAL; pi: REAL;

  PROCEDURE Frac(v: REAL): REAL;
  BEGIN RETURN v - FLT(FLOOR(v)) END Frac;

  PROCEDURE Noise(): REAL;
  BEGIN
    noiseSeed := noiseSeed + 0.7548776662;
    RETURN Frac(Math.sin(noiseSeed * 12.9898) * 43758.5453) * 2.0 - 1.0
  END Noise;

  PROCEDURE Curata*(VAR b: ARRAY OF REAL; n: INTEGER);
    VAR k: INTEGER;
  BEGIN FOR k := 0 TO n - 1 DO b[k] := 0.0 END
  END Curata;

  PROCEDURE NormalizeOctave*(f: REAL): REAL;
  BEGIN
    WHILE f > 2000.0 DO f := f / 2.0 END;
    WHILE f < 100.0 DO f := f * 2.0 END;
    RETURN f
  END NormalizeOctave;

  (* nodul cubului cel mai apropiat de frecventa hz (in orice octava); intoarce frecventa nodului adusa langa hz *)
  PROCEDURE Aproape*(hz: REAL; VAR bx, by, bz: INTEGER): REAL;
    VAR x, y, z: INTEGER; f, err, best, bf: REAL;
  BEGIN
    best := 1.0E9; bf := hz; bx := 0; by := 0; bz := 0;
    FOR x := 0 TO 6 DO
      FOR y := 0 TO 6 DO
        FOR z := 0 TO 6 DO
          f := Nephilim.Freq(x, y, z);
          WHILE f >= hz * 1.41421 DO f := f / 2.0 END;
          WHILE f < hz / 1.41421 DO f := f * 2.0 END;
          err := ABS(Math.ln(f / hz));
          IF (err < best - 0.0001) OR (ABS(err - best) <= 0.0001) & (x + y + z < bx + by + bz) THEN
            best := err; bf := f; bx := x; by := y; bz := z
          END
        END
      END
    END
    RETURN bf
  END Aproape;

  (* coarda ciupita (din MeetZ7.Pluck): se aduna in b *)
  PROCEDURE Pluck*(VAR b: ARRAY OF REAL; freq, energy, bright: REAL; nSamples: INTEGER);
    VAR i, kn, read: INTEGER; kbuf: ARRAY 2205 OF REAL; cur, nxt, decay, amp: REAL;
  BEGIN
    kn := FLOOR(44100.0 / freq);
    IF kn < 4 THEN kn := 4 END;
    IF kn > 2205 THEN kn := 2205 END;
    amp := energy * 9000.0;
    decay := 0.995 - 0.05 * (1.0 - energy);
    FOR i := 0 TO kn - 1 DO kbuf[i] := amp * Noise() END;
    read := 0;
    FOR i := 0 TO nSamples - 1 DO
      cur := kbuf[read];
      nxt := kbuf[(read + 1) MOD kn];
      kbuf[read] := (bright * cur + (1.0 - bright) * nxt) * decay;
      b[i] := b[i] + cur;
      read := (read + 1) MOD kn
    END
  END Pluck;

  (* Corpuscul (din SonicZ7.RenderCorpuscul): click percutant *)
  PROCEDURE Corpuscul*(VAR b: ARRAY OF REAL; freq: REAL);
    VAR k, attackN: INTEGER; t, o, env: REAL;
  BEGIN
    attackN := Scurt DIV 8;
    FOR k := 0 TO Scurt - 1 DO
      t := FLT(k) / 44100.0;
      o := Math.sin(2.0 * pi * freq * t);
      IF k < attackN THEN env := FLT(k) / FLT(attackN)
      ELSE env := 1.0 - FLT(k - attackN) / FLT(Scurt - attackN)
      END;
      b[k] := b[k] + 9000.0 * o * env
    END
  END Corpuscul;

  (* SuperPozitie (ca in MeetZ7): fundamentala, cvinta si octava, ciupite deodata *)
  PROCEDURE SuperPos*(VAR b: ARRAY OF REAL; freq, energy: REAL; n: INTEGER);
  BEGIN
    Pluck(b, freq, energy, 0.85, n);
    Pluck(b, freq * 1.5, energy * 0.6, 0.85, n);
    Pluck(b, freq * 2.0, energy * 0.4, 0.85, n)
  END SuperPos;

  (* coada: ultimele m esantioane se sting, ca sunetul sa nu se taie brusc *)
  PROCEDURE Stinge*(VAR b: ARRAY OF REAL; n, m: INTEGER);
    VAR k: INTEGER;
  BEGIN
    IF m > n THEN m := n END;
    FOR k := 0 TO m - 1 DO b[n - m + k] := b[n - m + k] * FLT(m - k) / FLT(m) END
  END Stinge;

BEGIN
  noiseSeed := 0.12345; pi := 3.14159265
END CorziZ7.

MODULE Labirint;  (* labirint cu melodie, ca aplicatie Android. O faci cu:  apk Labirint.Mod Labirint
   Fisierul are trei module: Nephilim (cubul Z7), CorziZ7 (instrumentele din SonicZ7/MeetZ7) si Labirint.
   Inclini telefonul si bila se rostogoleste. Fiecare labirint e o fraza din Oda bucuriei (Beethoven), cu notele
   luate din cubul Z7: Do (0,0,0), Re (2,0,0), Mi (6,0,1), Fa (0,0,3), Sol (1,0,0).
   Prima trecere: cauti drumul. Notele sunt ascunse; se arata cand bila ajunge langa ele si suna cand treci peste.
   A doua trecere: acelasi labirint, acum in ritm. Lumina aurie merge pe drum in tempoul melodiei; tine pasul cu ea.
   Dupa toate patru frazele, melodia se reia mai repede. *)
  IMPORT Math, Strings, Os, Ecran, Senzor, Sunet, CorziZ7;

  CONST C = 7; R = 11; NC = 77;   (* coloane, randuri, celule; startul e sus-stanga, iesirea jos-dreapta *)
    MaxN = 24;                    (* note intr-o fraza *)
    Raza = 0.27;                  (* raza bilei, in celule *)
    Accel = 60.0;                 (* celule/s^2 la o inclinare de 1 g: cat de repede o ia bila la vale *)
    Frecare = 2.6;                (* cat franeaza pe secunda: mai mare = bila mai grea, se opreste mai repede *)
    VMax = 6.5;                   (* celule/s *)
    Mort = 20.0;                  (* inclinarile mai mici de atat (miimi de g) nu misca bila: tremurul mainii *)
    Neted = 0.22;                 (* cat de tare netezesc senzorul (mai mic = mai lin, dar raspunde mai incet) *)
    Toleranta = 3.0;              (* cat de departe de lumina (in optimi) mai e "in ritm" *)
    Vede = 1.4;                   (* de la ce distanta (celule) se arata o nota ascunsa *)
    Lung = CorziZ7.Lung;

  VAR est, sud, est2, sud2, vazut: ARRAY C, R OF BOOLEAN;   (* zid la est / la sud de celula *)
    stiva, drum, drum2: ARRAY NC OF INTEGER;   (* celula = i + j * C *)
    L, L2: INTEGER;                            (* lungimea drumului start -> iesire *)
    n, T, opt: INTEGER;                        (* note; cand vine ultima (optimi); milisecunde pe optime *)
    hz: ARRAY MaxN OF REAL;
    durata, t, poz, treapta: ARRAY MaxN OF INTEGER;
    nume: ARRAY MaxN, 4 OF CHAR;
    cantat, inRitm, aratat: ARRAY MaxN OF BOOLEAN;
    sunete: ARRAY MaxN, Lung OF REAL;          (* fiecare nota, calculata dinainte cu CorziZ7 *)
    tok: ARRAY CorziZ7.Scurt OF REAL;          (* bila lovind zidul *)
    acordF: ARRAY Lung OF REAL;                (* acordul de la iesire *)
    noduri: ARRAY 96 OF CHAR;                  (* de unde vin notele: nodurile cubului *)
    prinse, nivel, stare, trecere: INTEGER;    (* stare: 0 = astept atingerea, 1 = joc, 2 = gata; trecere 1 sau 2 *)
    pornit, inainte, acord, ok: BOOLEAN;
    t0, ultim, sclipire, ultimTok, tFinal: INTEGER;   (* ms *)
    x, y, vx, vy: REAL;                        (* bila, in celule *)
    fx, fy, zx, zy: REAL;                      (* gravitatia netezita si zero-ul ei (miimi de g) *)
    seed: INTEGER;
    violet, violet2, aur, stins, verde, rosu, sticla: INTEGER;

  PROCEDURE Aleator(m: INTEGER): INTEGER;
  BEGIN
    seed := seed * 1103515245 + 12345
    RETURN (seed DIV 65536) MOD 32768 MOD m
  END Aleator;

  (* ---------------------------------------------------------------- melodia *)

  PROCEDURE Nod(ch: CHAR; tinta: REAL; VAR hzOut: REAL; nume0: ARRAY OF CHAR);   (* nota -> nodul Z7 + textul *)
    VAR bx, by, bz: INTEGER; i: INTEGER; gasit: BOOLEAN;
  BEGIN
    hzOut := CorziZ7.Aproape(tinta, bx, by, bz);
    gasit := FALSE; i := 0;
    WHILE (noduri[i] # 0X) & ~gasit DO
      IF (noduri[i] = nume0[0]) & (noduri[i + 1] = nume0[1]) THEN gasit := TRUE END;
      INC(i)
    END;
    IF ~gasit & (ch # "g") THEN
      IF noduri[0] # 0X THEN Strings.Append("   ", noduri) END;
      Strings.Append(nume0, noduri); Strings.Append(" ", noduri);
      Strings.AppendInt(bx, 0, noduri); Strings.Append(",", noduri);
      Strings.AppendInt(by, 0, noduri); Strings.Append(",", noduri);
      Strings.AppendInt(bz, 0, noduri)
    END
  END Nod;

  PROCEDURE Fraza(f: INTEGER);   (* litera = nota, cifra = durata in optimi; g = Sol de jos *)
    VAR s: ARRAY 64 OF CHAR; i, d: INTEGER; ch: CHAR;
  BEGIN
    IF f = 0 THEN s := "E2E2F2G2G2F2E2D2C2C2D2E2E3D1D4"
    ELSIF f = 2 THEN s := "D2D2E2C2D2E1F1E2C2D2E1F1E2D2C2D2g4"
    ELSE s := "E2E2F2G2G2F2E2D2C2C2D2E2D3C1C4"
    END;
    n := 0; d := 0; i := 0; noduri := "";
    WHILE (s[i] # 0X) & (n < MaxN) DO
      ch := s[i];
      IF ch = "g" THEN treapta[n] := 0; nume[n] := "Sol"; Nod(ch, 192.0, hz[n], "Sol")
      ELSIF ch = "C" THEN treapta[n] := 1; nume[n] := "Do"; Nod(ch, 256.0, hz[n], "Do")
      ELSIF ch = "D" THEN treapta[n] := 2; nume[n] := "Re"; Nod(ch, 288.0, hz[n], "Re")
      ELSIF ch = "E" THEN treapta[n] := 3; nume[n] := "Mi"; Nod(ch, 320.0, hz[n], "Mi")
      ELSIF ch = "F" THEN treapta[n] := 4; nume[n] := "Fa"; Nod(ch, 341.333, hz[n], "Fa")
      ELSE treapta[n] := 5; nume[n] := "Sol"; Nod(ch, 384.0, hz[n], "Sol")
      END;
      durata[n] := ORD(s[i + 1]) - ORD("0");
      t[n] := d; d := d + durata[n];
      INC(n); i := i + 2
    END;
    T := t[n - 1]
  END Fraza;

  PROCEDURE Instrumente;   (* optimile ciupite scurt (Corpuscul), patrimile ca Unda, notele lungi SuperPozitie *)
    VAR k: INTEGER;
  BEGIN
    FOR k := 0 TO n - 1 DO
      CorziZ7.Curata(sunete[k], Lung);
      IF durata[k] <= 1 THEN CorziZ7.Pluck(sunete[k], hz[k], 0.55, 0.5, Lung)
      ELSIF durata[k] <= 3 THEN CorziZ7.Pluck(sunete[k], hz[k], 0.85, 0.7, Lung)
      ELSE CorziZ7.SuperPos(sunete[k], hz[k], 1.0, Lung)
      END;
      CorziZ7.Stinge(sunete[k], Lung, 6000)
    END
  END Instrumente;

  (* ---------------------------------------------------------------- labirintul *)

  PROCEDURE Genereaza;   (* labirint perfect, prin backtracking; drumul e stiva in clipa cand ajunge la iesire *)
    VAR i, j, k, c, nv, sp: INTEGER; vec: ARRAY 4 OF INTEGER;
  BEGIN
    FOR i := 0 TO C - 1 DO
      FOR j := 0 TO R - 1 DO est[i, j] := TRUE; sud[i, j] := TRUE; vazut[i, j] := FALSE END
    END;
    sp := 0; stiva[0] := 0; vazut[0, 0] := TRUE; L := 0;
    WHILE sp >= 0 DO
      c := stiva[sp]; i := c MOD C; j := c DIV C;
      IF (c = NC - 1) & (L = 0) THEN
        L := sp + 1;
        FOR k := 0 TO sp DO drum[k] := stiva[k] END
      END;
      nv := 0;
      IF (i > 0) & ~vazut[i - 1, j] THEN vec[nv] := c - 1; INC(nv) END;
      IF (i < C - 1) & ~vazut[i + 1, j] THEN vec[nv] := c + 1; INC(nv) END;
      IF (j > 0) & ~vazut[i, j - 1] THEN vec[nv] := c - C; INC(nv) END;
      IF (j < R - 1) & ~vazut[i, j + 1] THEN vec[nv] := c + C; INC(nv) END;
      IF nv = 0 THEN DEC(sp)
      ELSE
        k := vec[Aleator(nv)];
        IF k = c - 1 THEN est[i - 1, j] := FALSE
        ELSIF k = c + 1 THEN est[i, j] := FALSE
        ELSIF k = c - C THEN sud[i, j - 1] := FALSE
        ELSE sud[i, j] := FALSE
        END;
        vazut[k MOD C, k DIV C] := TRUE;
        INC(sp); stiva[sp] := k
      END
    END
  END Genereaza;

  PROCEDURE Alege;   (* din 40 de labirinte: cel mai scurt drum in care tot incape o celula pe optime *)
    VAR a, i, j, k: INTEGER; bun: BOOLEAN;
  BEGIN
    L2 := 0;
    FOR a := 1 TO 40 DO
      Genereaza;
      IF L2 = 0 THEN bun := TRUE
      ELSIF L2 - 1 < T THEN bun := L > L2
      ELSE bun := (L - 1 >= T) & (L < L2)
      END;
      IF bun THEN
        L2 := L;
        FOR k := 0 TO L - 1 DO drum2[k] := drum[k] END;
        FOR i := 0 TO C - 1 DO FOR j := 0 TO R - 1 DO est2[i, j] := est[i, j]; sud2[i, j] := sud[i, j] END END
      END
    END;
    L := L2;
    FOR k := 0 TO L - 1 DO drum[k] := drum2[k] END;
    FOR i := 0 TO C - 1 DO FOR j := 0 TO R - 1 DO est[i, j] := est2[i, j]; sud[i, j] := sud2[i, j] END END
  END Alege;

  PROCEDURE Trecere(tr: INTEGER);   (* bila la start, notele necantate *)
    VAR k: INTEGER;
  BEGIN
    trecere := tr;
    FOR k := 0 TO n - 1 DO cantat[k] := FALSE; inRitm[k] := FALSE; aratat[k] := tr = 2 END;
    x := 0.5; y := 0.5; vx := 0.0; vy := 0.0;
    pornit := FALSE; acord := FALSE; prinse := 0
  END Trecere;

  PROCEDURE Pregateste;   (* fraza, labirintul, notele pe drum, tempoul, sunetele *)
    VAR k, m: INTEGER; viteza: REAL;
  BEGIN
    Fraza(nivel MOD 4);
    Alege;
    FOR k := 0 TO n - 1 DO poz[k] := FLOOR(FLT(t[k]) * FLT(L - 1) / FLT(T) + 0.5) END;
    FOR k := 1 TO n - 1 DO IF poz[k] <= poz[k - 1] THEN poz[k] := poz[k - 1] + 1 END END;
    FOR k := n - 1 TO 0 BY -1 DO m := L - n + k; IF poz[k] > m THEN poz[k] := m END END;
    viteza := 1.9 + 0.3 * FLT(nivel DIV 4);          (* celule pe secunda pentru lumina *)
    opt := FLOOR(FLT(L - 1) / FLT(T) / viteza * 1000.0);
    IF opt < 150 THEN opt := 150 END;
    Instrumente;
    Trecere(1);
    stare := 0
  END Pregateste;

  (* ---------------------------------------------------------------- bila *)

  PROCEDURE ZidV(i, j: INTEGER): BOOLEAN;   (* zidul vertical x = i, in randul j *)
    VAR z: BOOLEAN;
  BEGIN
    IF (j < 0) OR (j >= R) THEN z := FALSE
    ELSIF (i <= 0) OR (i >= C) THEN z := TRUE
    ELSE z := est[i - 1, j]
    END
    RETURN z
  END ZidV;

  PROCEDURE ZidO(i, j: INTEGER): BOOLEAN;   (* zidul orizontal y = j, in coloana i *)
    VAR z: BOOLEAN;
  BEGIN
    IF (i < 0) OR (i >= C) THEN z := FALSE
    ELSIF (j <= 0) OR (j >= R) THEN z := TRUE
    ELSE z := sud[i, j - 1]
    END
    RETURN z
  END ZidO;

  PROCEDURE Loveste(px, py: REAL): BOOLEAN;   (* bila in (px, py) atinge vreun zid? *)
    VAR i, j: INTEGER; z: BOOLEAN;
  BEGIN
    z := FALSE;
    FOR i := FLOOR(px - Raza) + 1 TO FLOOR(px + Raza) DO
      FOR j := FLOOR(py - Raza) TO FLOOR(py + Raza) DO IF ZidV(i, j) THEN z := TRUE END END
    END;
    FOR i := FLOOR(px - Raza) TO FLOOR(px + Raza) DO
      FOR j := FLOOR(py - Raza) + 1 TO FLOOR(py + Raza) DO IF ZidO(i, j) THEN z := TRUE END END
    END
    RETURN z
  END Loveste;

  PROCEDURE Prag(v: REAL): REAL;   (* zona moarta: o inclinare mica nu misca bila (bila grea nu topaie) *)
  BEGIN
    IF v > Mort THEN v := v - Mort ELSIF v < -Mort THEN v := v + Mort ELSE v := 0.0 END
    RETURN v
  END Prag;

  PROCEDURE Misca(dt: REAL);
    VAR ax, ay, nx, ny, f, v, tare: REAL; pasi, k: INTEGER;
  BEGIN
    ax := -Prag(fx - zx) / 1000.0 * Accel; ay := Prag(fy - zy) / 1000.0 * Accel;
    vx := vx + ax * dt; vy := vy + ay * dt;
    f := 1.0 - Frecare * dt; IF f < 0.0 THEN f := 0.0 END;
    vx := vx * f; vy := vy * f;
    v := Math.sqrt(vx * vx + vy * vy);
    IF v > VMax THEN vx := vx * VMax / v; vy := vy * VMax / v; v := VMax END;
    pasi := FLOOR(v * dt / 0.08) + 1; tare := 0.0;
    FOR k := 1 TO pasi DO
      nx := x + vx * dt / FLT(pasi);
      IF Loveste(nx, y) THEN
        IF ABS(vx) > tare THEN tare := ABS(vx) END;
        vx := 0.0
      ELSE x := nx
      END;
      ny := y + vy * dt / FLT(pasi);
      IF Loveste(x, ny) THEN
        IF ABS(vy) > tare THEN tare := ABS(vy) END;
        vy := 0.0
      ELSE y := ny
      END
    END;
    IF (tare > 2.0) & (Sunet.Ms() - ultimTok > 120) THEN Sunet.Reda(tok, CorziZ7.Scurt, 40); ultimTok := Sunet.Ms() END
  END Misca;

  PROCEDURE Canta(k: INTEGER; e: REAL);   (* nota k, cantata la e optimi de la pornire *)
  BEGIN
    cantat[k] := TRUE; aratat[k] := TRUE;
    inRitm[k] := (trecere = 2) & (ABS(e - FLT(t[k])) <= Toleranta);
    IF inRitm[k] THEN INC(prinse) END;
    Sunet.Reda(sunete[k], Lung, 85);
    sclipire := Sunet.Ms()
  END Canta;

  PROCEDURE Note;   (* notele de sub bila (si din jurul ei), si iesirea *)
    VAR c, k: INTEGER; e, dx, dy: REAL;
  BEGIN
    c := FLOOR(x) + FLOOR(y) * C;
    FOR k := 0 TO n - 1 DO
      dx := FLT(drum[poz[k]] MOD C) + 0.5 - x; dy := FLT(drum[poz[k]] DIV C) + 0.5 - y;
      IF dx * dx + dy * dy < Vede * Vede THEN aratat[k] := TRUE END
    END;
    IF ~pornit & (c # 0) THEN pornit := TRUE; t0 := Sunet.Ms(); Canta(0, 0.0) END;
    IF pornit THEN
      e := FLT(Sunet.Ms() - t0) / FLT(opt);
      FOR k := 1 TO n - 1 DO IF ~cantat[k] & (drum[poz[k]] = c) THEN Canta(k, e) END END;
      IF c = NC - 1 THEN stare := 2; tFinal := Sunet.Ms() END
    END
  END Note;

  PROCEDURE Lumina(VAR gx, gy: REAL);   (* unde e lumina acum, in celule *)
    VAR e, p, u: REAL; k, a, b: INTEGER;
  BEGIN
    p := 0.0;
    IF pornit THEN
      e := FLT(Sunet.Ms() - t0) / FLT(opt);
      IF e >= FLT(T) THEN p := FLT(L - 1)
      ELSE
        k := 0;
        WHILE (k < n - 2) & (FLT(t[k + 1]) <= e) DO INC(k) END;
        p := FLT(poz[k]) + FLT(poz[k + 1] - poz[k]) * (e - FLT(t[k])) / FLT(t[k + 1] - t[k])
      END
    END;
    a := FLOOR(p); IF a > L - 2 THEN a := L - 2 END;
    u := p - FLT(a); b := drum[a + 1]; a := drum[a];
    gx := FLT(a MOD C) + 0.5 + FLT(b MOD C - a MOD C) * u;
    gy := FLT(a DIV C) + 0.5 + FLT(b DIV C - a DIV C) * u
  END Lumina;

  (* ---------------------------------------------------------------- desenul *)

  PROCEDURE CuloareNota(k: INTEGER);
  BEGIN
    IF ~cantat[k] THEN Ecran.Culoare(stins)
    ELSIF trecere = 1 THEN Ecran.Culoare(aur)
    ELSIF inRitm[k] THEN Ecran.Culoare(verde)
    ELSE Ecran.Culoare(rosu)
    END
  END CuloareNota;

  PROCEDURE Banda(w, d: INTEGER);   (* sus: titlul si melodia, ca la karaoke *)
    VAR mx, lx, baza, pas, k, px, py, qx, qy: INTEGER; e: REAL; s: ARRAY 80 OF CHAR;
  BEGIN
    Ecran.Culoare(aur); Ecran.Text(w DIV 2, 30 * d, 18 * d, "LABIRINT");
    s := "Oda bucuriei  -  fraza "; Strings.AppendInt(nivel MOD 4 + 1, 0, s); Strings.Append(" din 4  -  ", s);
    IF trecere = 1 THEN Strings.Append("cauta drumul", s)
    ELSE Strings.AppendInt(30000 DIV opt, 0, s); Strings.Append(" batai/min", s)
    END;
    Ecran.Culoare(stins); Ecran.Text(w DIV 2, 48 * d, 11 * d, s);
    mx := 20 * d; lx := w - 2 * mx; baza := 104 * d; pas := 8 * d;
    Ecran.Grosime(d);
    FOR k := 1 TO n - 1 DO
      px := mx + t[k - 1] * lx DIV T; py := baza - treapta[k - 1] * pas;
      qx := mx + t[k] * lx DIV T; qy := baza - treapta[k] * pas;
      Ecran.Culoare(stins); Ecran.Linie(px, py, qx, qy)
    END;
    FOR k := 0 TO n - 1 DO
      px := mx + t[k] * lx DIV T; py := baza - treapta[k] * pas;
      CuloareNota(k);
      IF cantat[k] THEN Ecran.Disc(px, py, 5 * d) ELSE Ecran.Disc(px, py, 3 * d) END;
      Ecran.Text(px, baza + 16 * d, 9 * d, nume[k])
    END;
    IF pornit & (stare = 1) & (trecere = 2) THEN
      e := FLT(Sunet.Ms() - t0) / FLT(opt);
      IF e > FLT(T) THEN e := FLT(T) END;
      px := mx + FLOOR(e / FLT(T) * FLT(lx));
      Ecran.Culoare(aur); Ecran.Grosime(2 * d); Ecran.Linie(px, baza - 6 * pas, px, baza + 4 * d)
    END
  END Banda;

  PROCEDURE Mesaj(w, h, d: INTEGER; a, b, c, e: ARRAY OF CHAR);   (* un patrat in mijloc, cu 4 randuri *)
    VAR l, x0, y0, g: INTEGER;
  BEGIN
    l := w * 3 DIV 5; IF l > 210 * d THEN l := 210 * d END;
    x0 := (w - l) DIV 2; y0 := (h - l) DIV 2; g := 2 * d;
    Ecran.Culoare(aur); Ecran.Dreptunghi(x0 - g, y0 - g, l + 2 * g, l + 2 * g);
    Ecran.Culoare(violet2); Ecran.Dreptunghi(x0, y0, l, l);
    Ecran.Culoare(aur); Ecran.Text(w DIV 2, y0 + l * 30 DIV 100, 17 * d, a);
    Ecran.Culoare(sticla); Ecran.Text(w DIV 2, y0 + l * 50 DIV 100, 12 * d, b);
    Ecran.Text(w DIV 2, y0 + l * 62 DIV 100, 12 * d, c);
    Ecran.Culoare(stins); Ecran.Text(w DIV 2, y0 + l * 83 DIV 100, 10 * d, e)
  END Mesaj;

  PROCEDURE Deseneaza*;   (* o cheama aplicatia la fiecare cadru *)
    VAR w, h, d, s, ox, oy, sus, jos, i, j, k, c, acum, g, r, px, py: INTEGER;
      dt, gx, gy, faza: REAL; m1, m2: ARRAY 64 OF CHAR;
  BEGIN
    w := Ecran.Latime(); h := Ecran.Inaltime(); d := Ecran.Densitate() DIV 100 + 1;
    acum := Sunet.Ms();
    dt := FLT(acum - ultim) / 1000.0; ultim := acum;
    IF dt > 0.05 THEN dt := 0.05 ELSIF dt < 0.0 THEN dt := 0.0 END;
    Ecran.Fond(violet);
    IF ~ok THEN
      Ecran.Culoare(aur); Ecran.Text(w DIV 2, h DIV 2, 16 * d, "Telefonul n-are senzor de gravitatie")
    ELSE
      fx := fx + (FLT(Senzor.GX()) - fx) * Neted;
      fy := fy + (FLT(Senzor.GY()) - fy) * Neted;
      IF stare = 1 THEN Misca(dt); Note END;
      IF (stare = 2) & ~acord & (acum - tFinal > 450) THEN acord := TRUE; Sunet.Reda(acordF, Lung, 60) END;

      Banda(w, d);
      sus := 132 * d; jos := 36 * d;
      s := (w - 24 * d) DIV C;
      IF (h - sus - jos) DIV R < s THEN s := (h - sus - jos) DIV R END;
      ox := (w - C * s) DIV 2; oy := sus + (h - sus - jos - R * s) DIV 2;

      (* lumina (doar in a doua trecere): un halou sub ziduri *)
      Lumina(gx, gy);
      IF pornit & (stare = 1) & (trecere = 2) THEN
        Ecran.Culoare(violet2); Ecran.Disc(ox + FLOOR(gx * FLT(s)), oy + FLOOR(gy * FLT(s)), s * 9 DIV 20)
      END;
      (* notele de pe drum: in prima trecere doar cele gasite *)
      FOR k := 0 TO n - 1 DO
        IF aratat[k] THEN
          c := drum[poz[k]];
          px := ox + (c MOD C) * s + s DIV 2; py := oy + (c DIV C) * s + s DIV 2;
          CuloareNota(k);
          IF cantat[k] THEN Ecran.Disc(px, py, s * 4 DIV 25) ELSE Ecran.Disc(px, py, s * 3 DIV 25) END
        END
      END;
      (* zidurile *)
      g := s DIV 12; IF g < 2 THEN g := 2 END;
      Ecran.Culoare(aur); Ecran.Grosime(g);
      FOR i := 0 TO C - 1 DO
        FOR j := 0 TO R - 1 DO
          px := ox + i * s; py := oy + j * s;
          IF est[i, j] & (i < C - 1) THEN Ecran.Linie(px + s, py, px + s, py + s); Ecran.Disc(px + s, py, g DIV 2); Ecran.Disc(px + s, py + s, g DIV 2) END;
          IF sud[i, j] & (j < R - 1) THEN Ecran.Linie(px, py + s, px + s, py + s); Ecran.Disc(px, py + s, g DIV 2); Ecran.Disc(px + s, py + s, g DIV 2) END
        END
      END;
      Ecran.Linie(ox, oy, ox + C * s, oy);
      Ecran.Linie(ox, oy, ox, oy + R * s);
      Ecran.Linie(ox + C * s, oy, ox + C * s, oy + R * s);
      Ecran.Linie(ox, oy + R * s, ox + (C - 1) * s, oy + R * s);
      (* iesirea: o sageata sub ultima celula *)
      px := ox + (C - 1) * s + s DIV 2; py := oy + R * s;
      Ecran.Triunghi(px - s DIV 5, py + s DIV 10, px + s DIV 5, py + s DIV 10, px, py + s * 3 DIV 10);
      (* bila *)
      px := ox + FLOOR(x * FLT(s)); py := oy + FLOOR(y * FLT(s)); r := FLOOR(Raza * FLT(s));
      IF acum - sclipire < 400 THEN
        Ecran.Culoare(aur); Ecran.Grosime(d * 2); Ecran.Cerc(px, py, r + (acum - sclipire) * s DIV 700)
      END;
      Ecran.Culoare(sticla); Ecran.Disc(px, py, r);
      Ecran.Culoare(aur); Ecran.Grosime(d * 2); Ecran.Cerc(px, py, r);
      (* lumina: inelul care bate tactul (o bataie = doua optimi) *)
      IF pornit & (stare = 1) & (trecere = 2) THEN
        faza := FLT((acum - t0) MOD (2 * opt)) / FLT(2 * opt);
        Ecran.Culoare(aur); Ecran.Grosime(d * 2);
        Ecran.Cerc(ox + FLOOR(gx * FLT(s)), oy + FLOOR(gy * FLT(s)), FLOOR(FLT(s) * (0.30 + 0.08 * (1.0 - faza))))
      END;

      IF stare = 0 THEN
        m1 := "Fraza "; Strings.AppendInt(nivel MOD 4 + 1, 0, m1);
        Mesaj(w, h, d, m1, "gaseste drumul", "atinge, apoi inclina", "");
        Ecran.Culoare(stins); Ecran.Text(w DIV 2, h - 14 * d, 10 * d, noduri)
      ELSIF (stare = 2) & (trecere = 1) THEN
        Mesaj(w, h, d, "Ai gasit drumul!", "acum canta-l in ritm,", "dupa lumina aurie", "atinge ca sa pornesti")
      ELSIF stare = 2 THEN
        m1 := ""; Strings.AppendInt(prinse, 0, m1); Strings.Append(" din ", m1); Strings.AppendInt(n, 0, m1);
        IF prinse = n THEN m2 := "Perfect, la tempo!" ELSE m2 := "verde = in ritm" END;
        Mesaj(w, h, d, m1, "note in ritm", m2, "atinge: fraza urmatoare")
      ELSE
        Ecran.Culoare(stins); Ecran.Text(w DIV 2, h - 14 * d, 10 * d, "atinge ecranul ca sa recentrezi inclinarea")
      END
    END
  END Deseneaza;

  PROCEDURE Atinge*;   (* la apasare: porneste, recentreaza, trece la ritm sau la fraza urmatoare *)
    VAR acum: BOOLEAN;
  BEGIN
    acum := Ecran.Apasat();
    IF acum & ~inainte THEN
      IF stare = 0 THEN zx := fx; zy := fy; stare := 1; ultim := Sunet.Ms()
      ELSIF stare = 1 THEN zx := fx; zy := fy
      ELSIF trecere = 1 THEN Trecere(2); zx := fx; zy := fy; stare := 1; ultim := Sunet.Ms()
      ELSE INC(nivel); Pregateste
      END
    END;
    inainte := acum
  END Atinge;

BEGIN
  violet := Ecran.RGB(22, 4, 42); violet2 := Ecran.RGB(44, 14, 78);
  aur := Ecran.RGB(201, 168, 94); stins := Ecran.RGB(140, 116, 70);
  verde := Ecran.RGB(92, 214, 130); rosu := Ecran.RGB(222, 112, 128); sticla := Ecran.RGB(214, 196, 120);
  seed := Os.CurrentTime() * 7919 + Sunet.Ms();
  fx := 0.0; fy := 0.0; zx := 0.0; zy := 0.0;
  nivel := 0; inainte := FALSE; ultim := Sunet.Ms(); sclipire := -1000; ultimTok := 0;
  CorziZ7.Curata(tok, CorziZ7.Scurt); CorziZ7.Corpuscul(tok, 128.0);
  CorziZ7.Curata(acordF, Lung); CorziZ7.SuperPos(acordF, 256.0, 0.9, Lung);
  CorziZ7.Pluck(acordF, 318.94, 0.6, 0.7, Lung); CorziZ7.Stinge(acordF, Lung, 8000);
  ok := Senzor.PornesteGravitatia();
  Pregateste
END Labirint.
