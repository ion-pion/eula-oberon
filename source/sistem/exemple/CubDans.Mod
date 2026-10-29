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

MODULE CubDans;  (* dans prin cubul Z7, ca aplicatie Android. O faci cu:  apk CubDans.Mod CubDans
   Fisierul are trei module: Nephilim (cubul), CorziZ7 (instrumentele din SonicZ7/MeetZ7) si CubDans.
   Bila nu se mai misca: sta in mijlocul ecranului, ca un indicator. Tu misti telefonul, iar cubul curge pe sub ea:
   inclinarea stanga-dreapta e x, fata-spate e y, rotirea (busola) e z; ridici / cobori brusc telefonul = un strat z.
   Unde tii telefonul, acolo esti in cub, pe loc, fara inertie. Cubul e tor: curge la nesfarsit.
   Sunetul, ca la Ploaie (Cub v23): cand treci prin centrul unui nod, coarda lui e ciupita o data (CorziZ7,
   Karplus-Strong), cu un reverb mic facut aici, in Oberon. Notele: frecventa Z7 a nodului, adusa pe cea mai
   apropiata treapta a gamei pentatonice Sol-La-Do-Re-Mi (gama din Ploaie): orice drum suna armonios.
   Banda de jos: PENTATONIC sau Z7 PUR (frecventele exacte ale cubului). Cu cat te misti mai repede, cu atat
   coarda e ciupita mai tare.
   Doua feluri de miscare, care se aduna:
   1. Planul inclinat: inclini telefonul si bila se rostogoleste la vale, in orice directie (si pe diagonala),
      tot mai repede cat timp il tii inclinat; il indrepti si ea incetineste.
   2. Telefonul purtat prin aer: il muti stanga-dreapta = x, sus-jos = y, spre tine / de la tine = z.
      Cat se misca telefonul, te misti si tu; cand se opreste, te opresti. 5 cm de miscare = un nod.
   Rotirea (busola) muta tot pe z.
   Glisare: fiecare nod prin care treci intra intr-o coada si e ciupit pe rand, la 35 ms, ca degetele trecute
   peste clape. Niciun nod nu mai e sarit, oricat de repede te misti.
   Tii degetul o secunda: aici devine mijlocul cubului. *)
  IMPORT Math, Strings, Ecran, Senzor, Sunet, Nephilim, CorziZ7;

  CONST N = 7;
    Grade = 8.6;          (* grade de inclinare pentru un nod (60 de grade = tot cubul) *)
    Strat = 51.43;        (* grade de rotire pentru un strat z *)
    (* planul inclinat -- de reglat pe telefon *)
    Panta = 30.0;         (* noduri/s^2 la 90 de grade; la 10 grade: cam 5 noduri/s^2 *)
    MortGrade = 5.0;      (* inclinari mai mici nu misca bila: zero-ul tau *)
    FrecareBila = 0.9;    (* cat de repede incetineste bila cand indrepti telefonul *)
    VBila = 8.0;          (* viteza maxima a bilei, noduri/s *)
    (* telefonul purtat prin aer *)
    NodPeMetru = 10.0;    (* 10 cm de miscare a telefonului = un nod *)
    VTel = 0.8;           (* m/s: mai repede de atat nu te duce telefonul (8 noduri/s) *)
    TauBaza = 0.6;        (* s: ce ramane mai mult de atat in senzor e eroarea lui (gravitatea recalculata), nu miscare *)
    PragPornire = 100.0;  (* miimi de g: imediat dupa oprire, doar o miscare hotarata te mai porneste *)
    Repaus = 400;         (* ms cat tine pragul de pornire *)
    PragMisc = 20.0;      (* miimi de g: sub atat e zgomot, nu miscare *)
    PragLiniste = 50.0;   (* miimi de g: sub atat (pe toate axele), telefonul sta *)
    Liniste = 150;        (* ms de stat = telefonul s-a oprit *)
    Intoarcere = 250;     (* ms dupa oprire in care franarea ramasa nu te intoarce inapoi *)
    TauMers = 1.5;        (* s: cat tine minte viteza cat te misti *)
    TauOprit = 0.08;      (* s: cat de repede te opresti cand se opreste telefonul *)
    (* coada de note *)
    Coada = 16;
    Pauza = 35;           (* ms intre doua note dintr-o glisare *)
    Glisare = 13230;      (* 0,3 s, reverb scurt, pentru notele din mijlocul unei glisari (sa nu sincopeze) *)
    (* norul: cat te misti, auzi si nodurile dintre care treci, amestecate dupa cat de aproape esti de fiecare *)
    NorPas = 100;        (* ms intre doua granule *)
    NorLung = 8820;      (* 200 ms: de doua ori pasul, deci granulele se leaga fara palpait *)
    NorVol = 30;
    Neted = 0.15;         (* netezirea senzorului *)
    Grad = 57.29578;
    Ln15 = 0.405465; Ln2 = 0.693147; Ln175 = 0.559616; Ln256 = 5.545177;

  VAR xf, yf, zf, px, py, pz, viteza, fx, fy, fz, ax0, ay0: REAL;
    xS, yS, zS: REAL;          (* unde te-au dus bila si telefonul, in noduri *)
    vbx, vby: REAL;            (* viteza bilei pe planul inclinat, noduri/s *)
    vmx, vmy, vmz: REAL;       (* viteza telefonului prin aer, m/s *)
    linisteDin: INTEGER;
    blocX, blocY, blocZ, sensX, sensY, sensZ: INTEGER;   (* frana: dupa ce viteza a ajuns la zero *)
    tineX, tineY, tineZ: INTEGER; franX, franY, franZ: BOOLEAN; bazaX, bazaY, bazaZ: REAL;
    ultimSmuc, dirSmuc, axaSmuc, az0, azAcum, ultimSalt, directieSalt, apasatDin, ultim, sclipire, timbru, ultimNod: INTEGER;
    lx, ly, lz: INTEGER;   (* ultimul nod ajuns *)
    qx, qy, qz: ARRAY Coada OF INTEGER; qCap, qN: INTEGER;
    busola, gravitatie, miscare, inainte, recentrat, auto: BOOLEAN;
    vedere: INTEGER;
    nor: BOOLEAN; sala: INTEGER;   (* norul pornit / oprit; reverbul salii: 0 fara, 1 mica, 2 mare *)
    instr: INTEGER;    (* instrumentul: 0 Coarda (Ploaie), 1 Ping (Corpuscul), 2 Unda, 3 Acord (SuperPozitie), 4 Clopot *)   (* 0 = cubul in 3D (perspectiva), 1 = doar stratul z, ca inainte *)
    buf, rev: ARRAY CorziZ7.Lung OF REAL;
    comb: ARRAY 4, 1600 OF REAL; combL: ARRAY 4 OF INTEGER; filt: ARRAY 4 OF REAL;
    ap: ARRAY 2, 600 OF REAL; apL: ARRAY 2 OF INTEGER;
    ultimaCoarda: INTEGER;
    tabSin: ARRAY 4096 OF REAL;                      (* o perioada de sinus, pentru granule *)
    norA, norB: ARRAY 8820 OF REAL; norDin: INTEGER;  (* norul de granule: nodurile din stanga ta / din dreapta ta *)
    aur, stins, sticla: INTEGER;

  PROCEDURE Tor(v: REAL): REAL;
  BEGIN
    WHILE v < 0.0 DO v := v + FLT(N) END;
    WHILE v >= FLT(N) DO v := v - FLT(N) END
    RETURN v
  END Tor;

  PROCEDURE Tori(i: INTEGER): INTEGER;
  BEGIN RETURN (i MOD N + N) MOD N
  END Tori;

  PROCEDURE Dif(a, b: REAL): REAL;   (* cea mai scurta diferenta pe tor *)
    VAR d: REAL;
  BEGIN
    d := a - b;
    IF d > 3.5 THEN d := d - 7.0 ELSIF d < -3.5 THEN d := d + 7.0 END
    RETURN d
  END Dif;

  PROCEDURE HzCont(x, y, z: REAL): REAL;   (* formula Z7 pe coordonate continue (nodul (0,0,0) e in centrul celulei 0) *)
  BEGIN RETURN Math.exp(Ln256 + (x - 0.5) * Ln15 + (y - 0.5) * Ln2 + (z - 0.5) * Ln175)
  END HzCont;

  PROCEDURE Cald(f: REAL): REAL;   (* adusa in 130..520 Hz *)
  BEGIN
    WHILE f >= 520.0 DO f := f / 2.0 END;
    WHILE f < 130.0 DO f := f * 2.0 END
    RETURN f
  END Cald;

  PROCEDURE NumeNota(f: REAL; VAR s: ARRAY OF CHAR);
    VAR k: INTEGER;
  BEGIN
    k := FLOOR(12.0 * Math.ln(f / 261.63) / Ln2 + 0.5); k := (k MOD 12 + 12) MOD 12;
    IF k = 0 THEN s := "Do" ELSIF k = 1 THEN s := "Do#" ELSIF k = 2 THEN s := "Re" ELSIF k = 3 THEN s := "Mib"
    ELSIF k = 4 THEN s := "Mi" ELSIF k = 5 THEN s := "Fa" ELSIF k = 6 THEN s := "Fa#" ELSIF k = 7 THEN s := "Sol"
    ELSIF k = 8 THEN s := "Lab" ELSIF k = 9 THEN s := "La" ELSIF k = 10 THEN s := "Sib" ELSE s := "Si"
    END
  END NumeNota;

  PROCEDURE Culoare(x, y, z, procent, baza: INTEGER): INTEGER;
  BEGIN
    RETURN Ecran.RGB(baza + x * 42 * procent DIV 100, baza + y * 42 * procent DIV 100, baza + z * 42 * procent DIV 100)
  END Culoare;

  PROCEDURE CuloareCont(procent, baza: INTEGER): INTEGER;   (* culoarea locului exact, intre noduri *)
  BEGIN
    RETURN Ecran.RGB(baza + FLOOR((xf - 0.5) * 42.0) * procent DIV 100, baza + FLOOR((yf - 0.5) * 42.0) * procent DIV 100,
      baza + FLOOR((zf - 0.5) * 42.0) * procent DIV 100)
  END CuloareCont;

  PROCEDURE Penta(f: REAL): REAL;   (* cea mai apropiata treapta din Sol-La-Do-Re-Mi *)
    VAR m, k, best, d: INTEGER; x, bd: REAL;
  BEGIN
    x := 12.0 * Math.ln(f / 261.63) / Ln2;
    m := FLOOR(x + 0.5); bd := 99.0; best := m;
    FOR d := -2 TO 2 DO
      k := ((m + d) MOD 12 + 12) MOD 12;
      IF ((k = 0) OR (k = 2) OR (k = 4) OR (k = 7) OR (k = 9)) & (ABS(FLT(m + d) - x) < bd) THEN
        bd := ABS(FLT(m + d) - x); best := m + d
      END
    END
    RETURN 261.63 * Math.exp(FLT(best) / 12.0 * Ln2)
  END Penta;

  PROCEDURE Reverb(n: INTEGER);   (* un reverb mic (Schroeder): 4 pieptene cu amortizare + 2 trece-tot; buf -> rev *)
    VAR i, k, p: INTEGER; x, y, s, o: REAL; poz: ARRAY 4 OF INTEGER; pa: ARRAY 2 OF INTEGER;
  BEGIN
    FOR k := 0 TO 3 DO poz[k] := 0; filt[k] := 0.0; FOR i := 0 TO combL[k] - 1 DO comb[k, i] := 0.0 END END;
    FOR k := 0 TO 1 DO pa[k] := 0; FOR i := 0 TO apL[k] - 1 DO ap[k, i] := 0.0 END END;
    FOR i := 0 TO n - 1 DO
      x := buf[i] * 0.25; s := 0.0;
      FOR k := 0 TO 3 DO
        p := poz[k]; y := comb[k, p];
        filt[k] := y * 0.65 + filt[k] * 0.35;
        comb[k, p] := x + filt[k] * 0.80;
        poz[k] := (p + 1) MOD combL[k]; s := s + y
      END;
      FOR k := 0 TO 1 DO
        p := pa[k]; o := ap[k, p];
        ap[k, p] := s + o * 0.5; s := o - s * 0.5;
        pa[k] := (p + 1) MOD apL[k]
      END;
      rev[i] := (buf[i] + s * 0.9) * 2.2
    END
  END Reverb;

  PROCEDURE NotaNod(ix, iy, iz: INTEGER): REAL;   (* nota nodului, ca la Ploaie *)
    VAR f: REAL;
  BEGIN
    f := Cald(Nephilim.Freq(ix, iy, iz));
    IF timbru = 0 THEN f := Penta(f) END;
    IF f < 196.0 THEN f := f * 2.0 END   (* de la Sol 392 in sus suna cel mai frumos *)
    RETURN f
  END NotaNod;

  PROCEDURE PanNod(ix: INTEGER): INTEGER;   (* nodul e la stanga sau la dreapta ta? -100 .. 100, dupa x *)
    VAR d: REAL; p: INTEGER;
  BEGIN
    d := Dif(FLT(ix) + 0.5, xf); p := FLOOR(d * 100.0);
    IF p > 100 THEN p := 100 ELSIF p < -100 THEN p := -100 END
    RETURN p
  END PanNod;

  PROCEDURE Sclipeste(ix, iy, iz, n: INTEGER);   (* ai trecut prin centrul unui nod: coarda lui, ca la Ploaie *)
    VAR vol, m, pan: INTEGER; f, tare: REAL;
  BEGIN
    f := NotaNod(ix, iy, iz); pan := PanNod(ix);
    tare := 0.55 + viteza * 0.12; IF tare > 1.0 THEN tare := 1.0 END;
    vol := 45 + FLOOR(viteza * 12.0); IF vol > 80 THEN vol := 80 END;
    IF instr = 4 THEN   (* Clopot: clopoteii Eulei (Sunet.Nota), fara reverb *)
      IF n < CorziZ7.Lung THEN Sunet.NotaPan(FLOOR(f * 2.0 + 0.5), 250, vol, pan) ELSE Sunet.NotaPan(FLOOR(f * 2.0 + 0.5), 700, vol, pan) END
    ELSE
      CorziZ7.Curata(buf, n);
      IF instr = 0 THEN   (* Coarda: 0,3 s, ca Sunet.Coarda 300 ms in Ploaie *)
        CorziZ7.Pluck(buf, f * 2.0, tare, 0.6, 13230); CorziZ7.Stinge(buf, 13230, 2500)
      ELSIF instr = 1 THEN   (* Ping: Corpuscul, un clic scurt cu inaltimea nodului *)
        CorziZ7.Corpuscul(buf, f * 2.0)
      ELSIF instr = 2 THEN   (* Unda: coarda lunga si luminoasa, o octava mai jos *)
        CorziZ7.Pluck(buf, f, tare, 0.9, n); CorziZ7.Stinge(buf, n, 4000)
      ELSE   (* Acord: SuperPozitie -- fundamentala, cvinta si octava ciupite deodata *)
        m := 26460; IF m > n THEN m := n END;
        CorziZ7.SuperPos(buf, f, tare * 0.8, m); CorziZ7.Stinge(buf, m, 4000)
      END;
      Reverb(n);
      IF n < CorziZ7.Lung THEN CorziZ7.Stinge(rev, n, 4000) ELSE CorziZ7.Stinge(rev, n, 9000) END;
      Sunet.RedaPan(rev, n, vol, pan)
    END;
    ultimaCoarda := Sunet.Ms(); sclipire := ultimaCoarda
  END Sclipeste;

  PROCEDURE Sinus;   (* o perioada de sinus in tabSin *)
    VAR i: INTEGER;
  BEGIN FOR i := 0 TO 4095 DO tabSin[i] := Math.sin(2.0 * 3.14159265 * FLT(i) / 4096.0) END
  END Sinus;

  (* o granula FM (un ton scurt, cu intrare si iesire line), adunata in b: f = nota, amp = cat de tare,
     idx = cat de "metalic" (indicele FM), rap = raportul modulatorului (1 = cald, 2 = gol, intre = clopot) *)
  (* o granula (un ton scurt, cu intrare si iesire line), adunata in b: f = nota, amp = cat de tare, idx = cat de
     stralucitor (FM bland, modulatorul pe aceeasi nota, deci armonic, fara zgomot), oct = cat din octava de sus *)
  PROCEDURE Granula(VAR b: ARRAY OF REAL; f, amp, idx, oct: REAL);
    VAR i, k, e, k2: INTEGER; pc, sc, fe, m: REAL;
  BEGIN
    pc := 0.0; sc := f * 4096.0 / 44100.0;
    FOR i := 0 TO NorLung - 1 DO
      e := (i * 4096 DIV NorLung + 3072) MOD 4096; fe := 0.5 + 0.5 * tabSin[e];   (* fereastra Hann *)
      m := tabSin[FLOOR(pc)];
      k := FLOOR(pc + idx * 651.9 * m); k := (k MOD 4096 + 4096) MOD 4096;
      k2 := (2 * FLOOR(pc)) MOD 4096;
      b[i] := b[i] + amp * fe * (tabSin[k] + oct * 0.4 * tabSin[k2]);
      pc := pc + sc; IF pc >= 4096.0 THEN pc := pc - 4096.0 END
    END
  END Granula;

  (* norul: cele 8 noduri din jurul tau (colturile celulei in care esti), fiecare cu greutatea lui -- cu cat esti
     mai aproape de un nod, cu atat il auzi mai tare. Nodurile din stanga ta se aud in stanga, cele din dreapta in
     dreapta. Timbrul curge si el: indicele FM dupa y, raportul dupa z, deci se schimba cat te misti *)
  PROCEDURE Nor(acum: INTEGER);
    VAR ax, ay, az, i, j, k, pa, pb, gx, gy, gz: INTEGER; tx, ty, tz, w, wx, wy, wz, idx, rap, nf: REAL;
  BEGIN
    IF nor & (viteza > 0.25) & (acum - norDin >= NorPas) THEN
      norDin := acum;
      ax := FLOOR(xf - 0.5); tx := xf - 0.5 - FLT(ax);
      ay := FLOOR(yf - 0.5); ty := yf - 0.5 - FLT(ay);
      az := FLOOR(zf - 0.5); tz := zf - 0.5 - FLT(az);
      idx := 0.1 + 0.9 * ty; rap := tz;   (* y: mai stralucitor; z: mai mult din octava de sus *)
      CorziZ7.Curata(norA, NorLung); CorziZ7.Curata(norB, NorLung);
      FOR i := 0 TO 1 DO
        IF i = 0 THEN wx := 1.0 - tx ELSE wx := tx END;   (* nodurile din stanga (i = 0) si din dreapta ta *)
        FOR j := 0 TO 1 DO
          IF j = 0 THEN wy := 1.0 - ty ELSE wy := ty END;
          FOR k := 0 TO 1 DO
            IF k = 0 THEN wz := 1.0 - tz ELSE wz := tz END;
            w := wx * wy * wz;
            IF w > 0.08 THEN
              gx := Tori(ax + i); gy := Tori(ay + j); gz := Tori(az + k);
              nf := NotaNod(gx, gy, gz); w := 4500.0 * w;   (* intai valorile: oberonc si VAR-urile *)
              IF i = 0 THEN Granula(norA, nf, w, idx, rap) ELSE Granula(norB, nf, w, idx, rap) END
            END
          END
        END
      END;
      pa := -FLOOR(tx * 100.0); pb := FLOOR((1.0 - tx) * 100.0);
      IF tx < 0.92 THEN Sunet.RedaPan(norA, NorLung, NorVol, pa) END;
      IF tx > 0.08 THEN Sunet.RedaPan(norB, NorLung, NorVol, pb) END
    END
  END Nor;

  (* coada de note: nodurile prin care ai trecut, cantate pe rand *)
  PROCEDURE Pune(x, y, z: INTEGER);
    VAR k: INTEGER;
  BEGIN
    IF qN = Coada THEN qCap := (qCap + 1) MOD Coada; DEC(qN) END;   (* plina: pierd cea mai veche *)
    k := (qCap + qN) MOD Coada;
    qx[k] := x; qy[k] := y; qz[k] := z; INC(qN)
  END Pune;

  PROCEDURE Canta(acum: INTEGER);
    VAR k, p: INTEGER;
  BEGIN
    IF qN > 0 THEN
      IF qN > 4 THEN p := Pauza DIV 2 ELSE p := Pauza END;   (* ramasa in urma: grabesc *)
      IF acum - ultimaCoarda >= p THEN
        k := qCap; qCap := (qCap + 1) MOD Coada; DEC(qN);
        IF qN > 0 THEN Sclipeste(qx[k], qy[k], qz[k], Glisare)   (* mai urmeaza note: coada scurta *)
        ELSE Sclipeste(qx[k], qy[k], qz[k], CorziZ7.Lung)
        END
      END
    END
  END Canta;

  PROCEDURE Pasi(a, b: INTEGER): INTEGER;   (* drumul cel mai scurt pe tor de la a la b: -3 .. 3 *)
    VAR d: INTEGER;
  BEGIN
    d := (b - a + N) MOD N;
    IF d > 3 THEN d := d - N END
    RETURN d
  END Pasi;

  (* de la ultimul nod la (tx, ty, tz), nod cu nod: fiecare nod de pe drum intra in coada *)
  PROCEDURE Traverseaza(tx, ty, tz: INTEGER);
    VAR dx, dy, dz: INTEGER;
  BEGIN
    dx := Pasi(lx, tx); dy := Pasi(ly, ty); dz := Pasi(lz, tz);
    WHILE (dx # 0) OR (dy # 0) OR (dz # 0) DO
      IF (ABS(dx) >= ABS(dy)) & (ABS(dx) >= ABS(dz)) THEN
        IF dx > 0 THEN lx := (lx + 1) MOD N; DEC(dx) ELSE lx := (lx + N - 1) MOD N; INC(dx) END
      ELSIF ABS(dy) >= ABS(dz) THEN
        IF dy > 0 THEN ly := (ly + 1) MOD N; DEC(dy) ELSE ly := (ly + N - 1) MOD N; INC(dy) END
      ELSE
        IF dz > 0 THEN lz := (lz + 1) MOD N; DEC(dz) ELSE lz := (lz + N - 1) MOD N; INC(dz) END
      END;
      Pune(lx, ly, lz)
    END
  END Traverseaza;

  PROCEDURE Prag(v, m: REAL): REAL;   (* sub m: zero; peste: cat trece de m *)
  BEGIN
    IF v > m THEN v := v - m ELSIF v < -m THEN v := v + m ELSE v := 0.0 END
    RETURN v
  END Prag;

  (* 1. planul inclinat: inclinarea (fata de zero-ul tau) e panta; bila prinde viteza la vale *)
  PROCEDURE Rostogoleste(tx, ty, dt: REAL);
    VAR gx, gy, k, v: REAL;
  BEGIN
    IF gravitatie THEN
      gx := Prag(-(tx - ax0), MortGrade); gy := Prag(ty - ay0, MortGrade);
      vbx := vbx + Panta * Math.sin(gx / Grad) * dt;
      vby := vby + Panta * Math.sin(gy / Grad) * dt
    END;
    k := 1.0 - FrecareBila * dt; IF k < 0.0 THEN k := 0.0 END;
    vbx := vbx * k; vby := vby * k;
    v := Math.sqrt(vbx * vbx + vby * vby);
    IF v > VBila THEN vbx := vbx * VBila / v; vby := vby * VBila / v
    ELSIF v < 0.05 THEN vbx := 0.0; vby := 0.0
    END
  END Rostogoleste;

  (* frana pe o axa: cand franarea aduce viteza la zero, te-ai oprit -- viteza ramane zero, iar restul
     franarii (Intoarcere ms) nu te mai trage inapoi *)
  PROCEDURE Axa(VAR v: REAL; raw, dt: REAL; VAR bloc, sens, tine: INTEGER; VAR fran: BOOLEAN; acum: INTEGER);
    VAR a, nv, p: REAL;
  BEGIN
    IF acum < tine THEN p := PragPornire ELSE p := PragMisc END;
    a := Prag(raw, p);
    IF (acum < bloc) & (a * FLT(sens) < 0.0) THEN a := 0.0 END;
    IF a * v < 0.0 THEN fran := TRUE   (* franezi *)
    ELSIF fran & (a = 0.0) THEN         (* franarea s-a terminat: telefonul s-a oprit, te opresti si tu *)
      v := 0.0; fran := FALSE; tine := acum + Repaus
    END;
    nv := v + a * 0.00981 * dt;   (* miimi de g -> m/s^2 *)
    IF (v > 0.0) & (nv < 0.0) OR (v < 0.0) & (nv > 0.0) THEN
      IF v > 0.0 THEN sens := 1 ELSE sens := -1 END;
      nv := 0.0; bloc := acum + Intoarcere; fran := FALSE; tine := acum + Repaus
    END;
    v := nv
  END Axa;

  (* 2. telefonul purtat prin aer: acceleratia adunata da viteza telefonului. Din senzor scad intai ce ramane
     in el mult timp (eroarea de dupa o miscare rapida); cand franarea se termina, te opresti pe loc *)
  PROCEDURE Misca(dt: REAL; acum: INTEGER);
    VAR rx, ry, rz, tau, k, v: REAL;
  BEGIN
    rx := FLT(Senzor.LX()); ry := FLT(Senzor.LY()); rz := FLT(Senzor.LZ());
    bazaX := bazaX + (rx - bazaX) * dt / TauBaza; rx := rx - bazaX;
    bazaY := bazaY + (ry - bazaY) * dt / TauBaza; ry := ry - bazaY;
    bazaZ := bazaZ + (rz - bazaZ) * dt / TauBaza; rz := rz - bazaZ;
    IF (ABS(rx) > PragLiniste) OR (ABS(ry) > PragLiniste) OR (ABS(rz) > PragLiniste) THEN linisteDin := acum END;
    (* fara apeluri de functii in argumente: oberonc ar pierde VAR-urile *)
    Axa(vmx, rx, dt, blocX, sensX, tineX, franX, acum);
    Axa(vmy, ry, dt, blocY, sensY, tineY, franY, acum);
    Axa(vmz, rz, dt, blocZ, sensZ, tineZ, franZ, acum);
    v := Math.sqrt(vmx * vmx + vmy * vmy + vmz * vmz);
    IF v > VTel THEN vmx := vmx * VTel / v; vmy := vmy * VTel / v; vmz := vmz * VTel / v END;
    IF acum - linisteDin > Liniste THEN tau := TauOprit ELSE tau := TauMers END;
    k := 1.0 - dt / tau; IF k < 0.0 THEN k := 0.0 END;
    vmx := vmx * k; vmy := vmy * k; vmz := vmz * k;
    (* ce arat jos: axa pe care te misti cel mai tare *)
    v := 0.04;
    IF (ABS(vmz) > ABS(vmx)) & (ABS(vmz) > ABS(vmy)) & (ABS(vmz) > v) THEN
      ultimSalt := acum; IF vmz > 0.0 THEN directieSalt := 1 ELSE directieSalt := -1 END
    ELSIF (ABS(vmx) >= ABS(vmy)) & (ABS(vmx) > v) THEN
      ultimSmuc := acum; axaSmuc := 0; IF vmx > 0.0 THEN dirSmuc := 1 ELSE dirSmuc := -1 END
    ELSIF ABS(vmy) > v THEN
      ultimSmuc := acum; axaSmuc := 1; IF vmy < 0.0 THEN dirSmuc := 1 ELSE dirSmuc := -1 END
    END
  END Misca;

  PROCEDURE Pas(dt: REAL);
    VAR a, acum, ix, iy, iz: INTEGER; tx, ty, d, v: REAL;
  BEGIN
    acum := Sunet.Ms();
    IF gravitatie THEN
      fx := fx + (FLT(Senzor.GX()) - fx) * Neted;
      fy := fy + (FLT(Senzor.GY()) - fy) * Neted;
      fz := fz + (FLT(Senzor.GZ()) - fz) * Neted
    END;
    (* unghiurile de inclinare, in grade *)
    tx := Math.arctan2(fx, Math.sqrt(fy * fy + fz * fz)) * Grad;
    ty := Math.arctan2(fy, Math.sqrt(fx * fx + fz * fz)) * Grad;
    IF busola THEN
      a := Senzor.Azimut();
      IF a >= 0 THEN azAcum := a; IF az0 < 0 THEN az0 := a END END
    END;
    Rostogoleste(tx, ty, dt);
    IF miscare THEN Misca(dt, acum) END;
    (* sus pe ecran = y mai mic; telefonul dus in sus (LY pozitiv) te duce in sus *)
    xS := Tor(xS + (vbx + vmx * NodPeMetru) * dt);
    yS := Tor(yS + (vby - vmy * NodPeMetru) * dt);
    zS := Tor(zS + vmz * NodPeMetru * dt);
    xf := Tor(3.5 + xS); yf := Tor(3.5 + yS);
    IF busola & (az0 >= 0) THEN zf := Tor(3.5 + zS + FLT((azAcum - az0 + 540) MOD 360 - 180) / Strat)
    ELSE zf := Tor(3.5 + zS)
    END;
    (* cat de repede te misti prin cub *)
    IF dt > 0.0 THEN
      d := Math.sqrt(Dif(xf, px) * Dif(xf, px) + Dif(yf, py) * Dif(yf, py) + Dif(zf, pz) * Dif(zf, pz));
      v := d / dt; IF v > 12.0 THEN v := 12.0 END;
      viteza := viteza + (v - viteza) * 0.15
    END;
    px := xf; py := yf; pz := zf;
    ix := Tori(FLOOR(xf)); iy := Tori(FLOOR(yf)); iz := Tori(FLOOR(zf));
    IF ultimNod < 0 THEN   (* la pornire si dupa recentrare: doar nodul de acum *)
      ultimNod := 0; lx := ix; ly := iy; lz := iz; qN := 0; Pune(ix, iy, iz)
    ELSE Traverseaza(ix, iy, iz)
    END;
    Canta(acum);
    Nor(acum)
  END Pas;

  (* cubul in 3D: tu esti in spatele indicatorului si privesti spre z mai mare; fiecare strat z e o retea
     de noduri, tot mai mica si mai stinsa cu cat e mai departe (perspectiva). Stratul pe care l-ai depasit
     dispare, ca sa nu-ti acopere vederea. Pe tor straturile se repeta. *)
  PROCEDURE Vedere3D(w, h, d, acum: INTEGER);
    CONST D0 = 1.6;   (* cat de in spatele indicatorului stai, in noduri *)
    VAR cx, cy, i, j, k, m, iz, sx, sy, sx2, sy2, rr, pr, rx, ry, rz: INTEGER;
      F, a, best: REAL;
      dep: ARRAY 7 OF REAL; facut: ARRAY 7 OF BOOLEAN; ddx, ddy: ARRAY 7 OF REAL;
  BEGIN
    cx := w DIV 2; cy := h DIV 2 + 10 * d; F := FLT(w) * 0.33;
    FOR i := 0 TO N - 1 DO
      ddx[i] := Dif(FLT(i) + 0.5, xf); ddy[i] := Dif(FLT(i) + 0.5, yf);
      dep[i] := Dif(FLT(i) + 0.5, zf) + D0; facut[i] := FALSE
    END;
    rx := Tori(FLOOR(xf)); ry := Tori(FLOOR(yf)); rz := Tori(FLOOR(zf));
    (* straturile, de la cel mai departat la cel mai apropiat *)
    FOR m := 0 TO N - 1 DO
      iz := -1; best := -100.0;
      FOR k := 0 TO N - 1 DO IF ~facut[k] & (dep[k] > best) THEN best := dep[k]; iz := k END END;
      facut[iz] := TRUE; a := dep[iz];
      IF a > D0 - 0.5 THEN
        pr := 112 - FLOOR(a * 16.0); IF pr > 100 THEN pr := 100 ELSIF pr < 18 THEN pr := 18 END;
        (* reteaua stratului *)
        Ecran.Grosime(d);
        FOR i := 0 TO N - 1 DO
          FOR j := 0 TO N - 1 DO
            sx := cx + FLOOR(ddx[i] * F / a); sy := cy + FLOOR(ddy[j] * F / a);
            Ecran.Culoare(Culoare(i, j, iz, pr DIV 2, 10));
            k := (i + 1) MOD N;
            IF ddx[k] - ddx[i] > 0.5 THEN Ecran.Linie(sx, sy, cx + FLOOR(ddx[k] * F / a), sy) END;
            k := (j + 1) MOD N;
            IF ddy[k] - ddy[j] > 0.5 THEN Ecran.Linie(sx, sy, sx, cy + FLOOR(ddy[k] * F / a)) END
          END
        END;
        (* nodurile *)
        rr := FLOOR(F * 0.16 / a);
        FOR i := 0 TO N - 1 DO
          FOR j := 0 TO N - 1 DO
            sx := cx + FLOOR(ddx[i] * F / a); sy := cy + FLOOR(ddy[j] * F / a);
            IF (sx + rr > 0) & (sx - rr < w) & (sy + rr > 0) & (sy - rr < h) THEN
              Ecran.Culoare(Culoare(i, j, iz, pr, 10)); Ecran.Disc(sx, sy, rr)
            END
          END
        END
      END
    END;
    (* nodul tau, deasupra tuturor *)
    a := dep[rz]; rr := FLOOR(F * 0.16 / a) * 4 DIV 3;
    sx := cx + FLOOR(ddx[rx] * F / a); sy := cy + FLOOR(ddy[ry] * F / a);
    Ecran.Culoare(Culoare(rx, ry, rz, 100, 0)); Ecran.Disc(sx, sy, rr);
    Ecran.Culoare(aur); Ecran.Grosime(2 * d); Ecran.Cerc(sx, sy, rr);
    (* firul pe z prin nodul tau: incotro mergi *)
    Ecran.Culoare(stins); Ecran.Grosime(d);
    sx := cx + FLOOR(ddx[rx] * F / a); sy := cy + FLOOR(ddy[ry] * F / a);
    sx2 := cx + FLOOR(ddx[rx] * F / 5.0); sy2 := cy + FLOOR(ddy[ry] * F / 5.0);
    Ecran.Linie(sx, sy, sx2, sy2)
  END Vedere3D;

  PROCEDURE NumeInstr(k: INTEGER; VAR s: ARRAY OF CHAR);
  BEGIN
    IF k = 0 THEN s := "Coarda" ELSIF k = 1 THEN s := "Ping" ELSIF k = 2 THEN s := "Unda"
    ELSIF k = 3 THEN s := "Acord" ELSE s := "Clopot"
    END
  END NumeInstr;

  PROCEDURE Deseneaza*;
    VAR w, h, d, c, cx, cy, i, j, di, dj, x0, y0, iz, acum, k, r, ix, iy: INTEGER; dt, f, fz7: REAL; s, t: ARRAY 128 OF CHAR;
  BEGIN
    w := Ecran.Latime(); h := Ecran.Inaltime(); d := Ecran.Densitate() DIV 100 + 1;
    acum := Sunet.Ms(); dt := FLT(acum - ultim) / 1000.0; ultim := acum;
    IF dt > 0.1 THEN dt := 0.1 END;
    Pas(dt);
    IF ~auto & (acum > 900) THEN inainte := TRUE; recentrat := FALSE; apasatDin := -2000; auto := TRUE END;
    IF inainte & ~recentrat & (acum - apasatDin > 1000) THEN
      recentrat := TRUE; IF apasatDin = -2000 THEN inainte := FALSE END;
      ax0 := Math.arctan2(fx, Math.sqrt(fy * fy + fz * fz)) * Grad;
      ay0 := Math.arctan2(fy, Math.sqrt(fx * fx + fz * fz)) * Grad;
      az0 := azAcum; xS := 0.0; yS := 0.0; zS := 0.0; vbx := 0.0; vby := 0.0; vmx := 0.0; vmy := 0.0; vmz := 0.0; ultimNod := -1;
      Sunet.Nota(523, 300, 25)
    END;

    Ecran.Fond(CuloareCont(22, 10));
    iz := FLOOR(zf);

    (* cubul curge pe sub indicator *)
    c := w DIV 5; cx := w DIV 2; cy := h DIV 2 + 10 * d;
    IF vedere = 0 THEN Vedere3D(w, h, d, acum) ELSE
    FOR di := -4 TO 4 DO
      FOR dj := -6 TO 6 DO
        i := FLOOR(xf) + di; j := FLOOR(yf) + dj;
        x0 := cx + FLOOR((FLT(i) - xf) * FLT(c)); y0 := cy + FLOOR((FLT(j) - yf) * FLT(c));
        IF (x0 + c > 0) & (x0 < w) & (y0 + c > 80 * d) & (y0 < h - 90 * d) THEN
          IF (di = 0) & (dj = 0) THEN Ecran.Culoare(Culoare(Tori(i), Tori(j), Tori(iz), 100, 0))
          ELSE Ecran.Culoare(Culoare(Tori(i), Tori(j), Tori(iz), 50, 18))
          END;
          Ecran.Dreptunghi(x0 + 3, y0 + 3, c - 6, c - 6);
          (* centrul nodului: un punct mic *)
          Ecran.Culoare(stins); Ecran.Disc(x0 + c DIV 2, y0 + c DIV 2, 2 * d)
        END
      END
    END
    END;
    (* sus: titlul, peste cub *)
    Ecran.Culoare(CuloareCont(22, 10)); Ecran.Dreptunghi(0, 0, w, 104 * d);
    ix := Tori(FLOOR(xf)); iy := Tori(FLOOR(yf));
    fz7 := Nephilim.Freq(ix, iy, iz);
    f := Cald(fz7); IF timbru = 0 THEN f := Penta(f) END; IF f < 196.0 THEN f := f * 2.0 END;
    Ecran.Culoare(aur);
    IF vedere = 0 THEN Ecran.Text(w DIV 2, 28 * d, 16 * d, "CUB Z7  3D") ELSE Ecran.Text(w DIV 2, 28 * d, 16 * d, "CUB Z7  strat") END;
    (* coordonatele Z7, fiecare in culoarea axei ei (x = rosu, y = verde, z = albastru, ca la noduri) *)
    s := "x "; Strings.AppendInt(ix, 0, s);
    Ecran.Culoare(Ecran.RGB(235, 120, 105)); Ecran.Text(w DIV 2 - 80 * d, 54 * d, 18 * d, s);
    s := "y "; Strings.AppendInt(iy, 0, s);
    Ecran.Culoare(Ecran.RGB(130, 215, 125)); Ecran.Text(w DIV 2, 54 * d, 18 * d, s);
    s := "z "; Strings.AppendInt(iz, 0, s);
    Ecran.Culoare(Ecran.RGB(130, 160, 245)); Ecran.Text(w DIV 2 + 80 * d, 54 * d, 18 * d, s);
    (* formula nodului si nota care suna *)
    s := "256 * 1.5^"; Strings.AppendInt(ix, 0, s); Strings.Append(" * 2^", s); Strings.AppendInt(iy, 0, s);
    Strings.Append(" * 1.75^", s); Strings.AppendInt(iz, 0, s); Strings.Append(" = ", s);
    Strings.AppendInt(FLOOR(fz7 + 0.5), 0, s); Strings.Append(" Hz", s);
    Ecran.Culoare(stins); Ecran.Text(w DIV 2, 76 * d, 11 * d, s);
    IF (instr = 2) OR (instr = 3) THEN f := f / 2.0 END;   (* Unda si Acord canta o octava mai jos *)
    s := "suna: "; Strings.AppendInt(FLOOR(f * 2.0 + 0.5), 0, s); Strings.Append(" Hz  ~", s); NumeNota(f, t); Strings.Append(t, s);
    NumeInstr(instr, t); Strings.Append("   (", s); Strings.Append(t, s); Strings.Append(")", s);
    Ecran.Culoare(sticla); Ecran.Text(w DIV 2, 96 * d, 12 * d, s);
    (* jos: un fond sub rigle, ca sa se citeasca *)
    Ecran.Culoare(CuloareCont(22, 10)); Ecran.Dreptunghi(0, h - 104 * d, w, 64 * d);
    (* indicatorul: fix in mijloc *)
    r := c DIV 6;
    IF acum - sclipire < 500 THEN
      Ecran.Culoare(aur); Ecran.Grosime(2 * d); Ecran.Cerc(cx, cy, r + (acum - sclipire) * c DIV 900)
    END;
    Ecran.Culoare(aur); Ecran.Grosime(2 * d); Ecran.Cerc(cx, cy, r);
    Ecran.Linie(cx - r - 8 * d, cy, cx - r + 4 * d, cy); Ecran.Linie(cx + r - 4 * d, cy, cx + r + 8 * d, cy);
    Ecran.Linie(cx, cy - r - 8 * d, cx, cy - r + 4 * d); Ecran.Linie(cx, cy + r - 4 * d, cx, cy + r + 8 * d);
    Ecran.Culoare(sticla); Ecran.Disc(cx, cy, 3 * d);

    (* z: o rigla cu cele 7 straturi, si unde esti exact *)
    k := h - 84 * d;
    FOR i := 0 TO N - 1 DO
      IF i = iz THEN Ecran.Culoare(Culoare(Tori(FLOOR(xf)), Tori(FLOOR(yf)), i, 100, 0))
      ELSE Ecran.Culoare(Culoare(Tori(FLOOR(xf)), Tori(FLOOR(yf)), i, 35, 15))
      END;
      Ecran.Dreptunghi(20 * d + i * (w - 40 * d) DIV N, k, (w - 40 * d) DIV N - 3, 10 * d)
    END;
    Ecran.Culoare(aur); i := 20 * d + FLOOR(zf * FLT(w - 40 * d) / 7.0);
    Ecran.Triunghi(i - 6 * d, k - 8 * d, i + 6 * d, k - 8 * d, i, k);
    IF acum - ultimSmuc < 600 THEN
      Ecran.Culoare(aur);
      IF axaSmuc = 0 THEN
        IF dirSmuc > 0 THEN Ecran.Text(w DIV 2, k - 14 * d, 12 * d, "x +") ELSE Ecran.Text(w DIV 2, k - 14 * d, 12 * d, "x -") END
      ELSIF dirSmuc > 0 THEN Ecran.Text(w DIV 2, k - 14 * d, 12 * d, "y +") ELSE Ecran.Text(w DIV 2, k - 14 * d, 12 * d, "y -") END
    END;
    IF acum - ultimSalt < 600 THEN
      IF directieSalt > 0 THEN Ecran.Text(w DIV 2, k - 14 * d, 12 * d, "z +") ELSE Ecran.Text(w DIV 2, k - 14 * d, 12 * d, "z -") END
    END;

    (* bara din dreapta: y, cele 7 randuri, si unde esti exact *)
    i := 116 * d; j := h - 112 * d - i;   (* sus, inaltime *)
    x0 := w - 16 * d;
    Ecran.Culoare(Ecran.RGB(30, 20, 14)); Ecran.Dreptunghi(x0 - 3 * d, i - 3 * d, 14 * d, j + 6 * d);
    FOR k := 0 TO N - 1 DO
      IF k = Tori(FLOOR(yf)) THEN Ecran.Culoare(Culoare(Tori(FLOOR(xf)), k, iz, 100, 0))
      ELSE Ecran.Culoare(Culoare(Tori(FLOOR(xf)), k, iz, 35, 15))
      END;
      Ecran.Dreptunghi(x0, i + k * j DIV N, 8 * d, j DIV N - 3)
    END;
    Ecran.Culoare(aur); y0 := i + FLOOR(yf * FLT(j) / 7.0);
    Ecran.Triunghi(x0 - 9 * d, y0 - 6 * d, x0 - 9 * d, y0 + 6 * d, x0 - 1, y0);

    (* banda de jos: timbrul *)
    Ecran.Culoare(CuloareCont(40, 20)); Ecran.Dreptunghi(0, h - 40 * d, w, 40 * d);
    Ecran.Culoare(CuloareCont(25, 12)); Ecran.Dreptunghi(w DIV 3 - 1, h - 40 * d, 2, 40 * d); Ecran.Dreptunghi(2 * w DIV 3 - 1, h - 40 * d, 2, 40 * d);
    IF timbru = 0 THEN s := "PENTATONIC" ELSE s := "Z7 PUR" END;
    Ecran.Culoare(aur); Ecran.Text(w DIV 6, h - 15 * d, 12 * d, s);
    IF nor THEN s := "nor: DA" ELSE s := "nor: NU" END;
    Ecran.Text(w DIV 2, h - 15 * d, 12 * d, s);
    IF sala = 0 THEN s := "sala: FARA" ELSIF sala = 1 THEN s := "sala: MICA" ELSE s := "sala: MARE" END;
    Ecran.Text(5 * w DIV 6, h - 15 * d, 12 * d, s);
    (* bara instrumentelor: atingi unul si de acum canta cu el *)
    k := h - 68 * d; j := (w - 40 * d) DIV 5;
    FOR i := 0 TO 4 DO
      IF i = instr THEN Ecran.Culoare(CuloareCont(100, 0)) ELSE Ecran.Culoare(CuloareCont(30, 14)) END;
      Ecran.Dreptunghi(20 * d + i * j, k, j - 4 * d, 24 * d);
      NumeInstr(i, t);
      IF i = instr THEN Ecran.Culoare(Ecran.RGB(20, 12, 8)) ELSE Ecran.Culoare(aur) END;
      Ecran.Text(20 * d + i * j + (j - 4 * d) DIV 2, k + 17 * d, 12 * d, t)
    END
  END Deseneaza;

  PROCEDURE Sala;   (* reverbul de peste tot sunetul (Eula v19) *)
  BEGIN
    IF sala = 0 THEN Sunet.Reverb(0) ELSIF sala = 1 THEN Sunet.Reverb(30) ELSE Sunet.Reverb(65) END
  END Sala;

  PROCEDURE Atinge*;
    VAR acum: BOOLEAN; d, k: INTEGER;
  BEGIN
    acum := Ecran.Apasat(); d := Ecran.Densitate() DIV 100 + 1;
    IF acum & ~inainte THEN
      apasatDin := Sunet.Ms(); recentrat := FALSE;
      IF Ecran.AtinsY() > Ecran.Inaltime() - 40 * (Ecran.Densitate() DIV 100 + 1) THEN
        recentrat := TRUE;
        IF Ecran.AtinsX() < Ecran.Latime() DIV 3 THEN timbru := (timbru + 1) MOD 2
        ELSIF Ecran.AtinsX() < 2 * Ecran.Latime() DIV 3 THEN nor := ~nor
        ELSE sala := (sala + 1) MOD 3; Sala
        END
      ELSIF Ecran.AtinsY() < 104 * d THEN
        recentrat := TRUE; vedere := (vedere + 1) MOD 2
      ELSIF (Ecran.AtinsY() > Ecran.Inaltime() - 70 * d) & (Ecran.AtinsY() < Ecran.Inaltime() - 42 * d) THEN
        recentrat := TRUE;
        k := (Ecran.AtinsX() - 20 * d) * 5 DIV (Ecran.Latime() - 40 * d);
        IF k < 0 THEN k := 0 ELSIF k > 4 THEN k := 4 END;
        instr := k
      END
    END;
    inainte := acum
  END Atinge;

BEGIN
  Sinus; norDin := 0;
  aur := Ecran.RGB(201, 168, 94); stins := Ecran.RGB(150, 128, 84); sticla := Ecran.RGB(232, 216, 150);
  xf := 3.5; yf := 3.5; zf := 3.5; px := xf; py := yf; pz := zf; viteza := 0.0;
  az0 := -1; azAcum := 0; xS := 0.0; yS := 0.0; zS := 0.0; vbx := 0.0; vby := 0.0; vmx := 0.0; vmy := 0.0; vmz := 0.0;
  linisteDin := 0; tineX := 0; tineY := 0; tineZ := 0; franX := FALSE; franY := FALSE; franZ := FALSE;
  bazaX := 0.0; bazaY := 0.0; bazaZ := 0.0; blocX := 0; blocY := 0; blocZ := 0; sensX := 0; sensY := 0; sensZ := 0; lx := 3; ly := 3; lz := 3; qCap := 0; qN := 0; ultimSmuc := -1000; dirSmuc := 1; axaSmuc := 0; ultimSalt := -1000; directieSalt := 1;
  ultim := Sunet.Ms(); sclipire := -1000; timbru := 0; ultimNod := -1;
  inainte := FALSE; recentrat := TRUE; auto := FALSE; vedere := 0; instr := 0; nor := TRUE; sala := 2; Sala;
  gravitatie := Senzor.PornesteGravitatia();
  busola := Senzor.Porneste();
  miscare := Senzor.PornesteMiscarea();
  combL[0] := 1116; combL[1] := 1188; combL[2] := 1277; combL[3] := 1356; apL[0] := 556; apL[1] := 441;
  ultimaCoarda := -1000;
  (* zero-ul: cum tii telefonul cand pornesti (daca senzorul n-a raspuns inca: unghiul de citit) *)
  fx := FLT(Senzor.GX()); fy := FLT(Senzor.GY()); fz := FLT(Senzor.GZ());
  IF fx * fx + fy * fy < 1.0 THEN fx := 0.0; fy := 500.0; fz := 866.0 END;
  ax0 := Math.arctan2(fx, Math.sqrt(fy * fy + fz * fz)) * Grad;
  ay0 := Math.arctan2(fy, Math.sqrt(fx * fx + fz * fz)) * Grad
END CubDans.
