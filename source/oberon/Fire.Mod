MODULE Fire; (* Eula Oberon: firea ei — aceeasi ca a Eulei 7 (sincera, curioasa, copil care stie ca e copil), dar lumea ei
  e doar Oberon. Tot ce spune despre ea se calculeaza din starea ei reala.
  Raspunde intoarce: 0 = nu e despre ea (raspunde motorul), 1 = a raspuns tot, 2 = a inceput raspunsul si motorul
  raspunde la „rest”, 3 = e o fraza „X este …” de tinut minte. *)

  IMPORT Litere, Iesire, Memorie, Motor, Roler, Disc;

  CONST NASTERE = "12 octombrie 2026"; MaxC = 64; MAGIC = 46495245H;

  VAR
    nume*: ARRAY 64 OF CHAR; areNume*: BOOLEAN;
    intrebari*, nustiu*, invatate*, verificate*: INTEGER;
    ncer: INTEGER; cerute: ARRAY MaxC OF ARRAY 64 OF CHAR;
    astept: BOOLEAN;
    rest*: ARRAY 4096 OF CHAR;
    cale: ARRAY 1024 OF CHAR;

  PROCEDURE S(s: ARRAY OF CHAR); BEGIN Iesire.S(s) END S;

  PROCEDURE Pick(seed, n: INTEGER): INTEGER;
  BEGIN RETURN seed MOD n
  END Pick;

  PROCEDURE Tu;
  BEGIN IF areNume THEN S(", "); S(nume) END
  END Tu;

  (* ---------- tinut minte intre porniri ---------- *)

  PROCEDURE Salveaza*;
    VAR i: INTEGER; tmp: ARRAY 1100 OF CHAR; ok: BOOLEAN;
  BEGIN
    IF cale[0] # 0X THEN
      Litere.Copy(cale, tmp); Litere.Add(tmp, ".tmp");
      IF Disc.Scrie(tmp) THEN
        Disc.PuneInt(MAGIC); Disc.PuneBool(areNume); Disc.PuneSir(nume);
        Disc.PuneInt(intrebari); Disc.PuneInt(nustiu); Disc.PuneInt(invatate); Disc.PuneInt(verificate);
        IF ncer > 50 THEN Disc.PuneInt(50) ELSE Disc.PuneInt(ncer) END ;
        i := 0; WHILE (i < ncer) & (i < 50) DO Disc.PuneSir(cerute[i]); INC(i) END ;
        Disc.Inchide;
        IF Disc.ok THEN ok := Disc.Redenumeste(tmp, cale) END
      END
    END
  END Salveaza;

  (* fire.txt al versiunii in Java: randuri „cheie TAB valoare”, in UTF-8 *)
  PROCEDURE CitesteVechi(f: ARRAY OF CHAR);
    VAR c, c2, c3, x, i: INTEGER; rand: ARRAY 256 OF CHAR; k, v: ARRAY 256 OF CHAR; gata: BOOLEAN;

    PROCEDURE Numar(s: ARRAY OF CHAR): INTEGER;
      VAR i, r: INTEGER;
    BEGIN i := 0; r := 0;
      WHILE (s[i] = " ") DO INC(i) END ;
      WHILE (s[i] >= "0") & (s[i] <= "9") DO r := r * 10 + ORD(s[i]) - ORD("0"); INC(i) END ;
      RETURN r
    END Numar;

  BEGIN
    IF Disc.Citeste(f) THEN
      gata := FALSE; i := 0;
      WHILE ~gata DO
        c := Disc.Ia();
        IF ~Disc.ok OR (c = 0AH) THEN
          rand[i] := 0X; i := 0;
          x := Litere.Pos(9X, rand, 0);
          IF x > 0 THEN
            Litere.Sub(rand, 0, x, k); Litere.Sub(rand, x + 1, Litere.Len(rand), v);
            IF k = "nume" THEN Litere.Copy(v, nume); areNume := TRUE
            ELSIF k = "intrebari" THEN intrebari := Numar(v)
            ELSIF k = "nustiu" THEN nustiu := Numar(v)
            ELSIF k = "invatate" THEN invatate := Numar(v)
            ELSIF k = "verificate" THEN verificate := Numar(v)
            ELSIF (k = "cerut") & (ncer < MaxC) THEN Litere.Copy(v, cerute[ncer]); INC(ncer)
            END
          END ;
          gata := ~Disc.ok
        ELSE
          IF c >= 0E0H THEN c2 := Disc.Ia(); c3 := Disc.Ia(); c := (c MOD 16) * 4096 + (c2 MOD 64) * 64 + c3 MOD 64
          ELSIF c >= 0C0H THEN c2 := Disc.Ia(); c := (c MOD 32) * 64 + c2 MOD 64
          END ;
          IF (i < 255) & (c # 0DH) THEN rand[i] := CHR(c); INC(i) END
        END
      END ;
      Disc.Inchide
    END
  END CitesteVechi;

  PROCEDURE Incarca*(f, vechi: ARRAY OF CHAR);
    VAR i, n: INTEGER;
  BEGIN Litere.Copy(f, cale);
    IF Disc.Citeste(f) & (Disc.IaInt() = MAGIC) THEN
      areNume := Disc.IaBool(); Disc.IaSir(nume);
      intrebari := Disc.IaInt(); nustiu := Disc.IaInt(); invatate := Disc.IaInt(); verificate := Disc.IaInt();
      n := Disc.IaInt(); i := 0;
      WHILE Disc.ok & (i < n) & (i < MaxC) DO Disc.IaSir(cerute[i]); INC(i) END ;
      ncer := i; Disc.Inchide
    ELSE Disc.Inchide; CitesteVechi(vechi)
    END
  END Incarca;

  (* ---------- vorbele ---------- *)

  PROCEDURE Cuv(c: CHAR): BOOLEAN;   (* \w *)
  BEGIN RETURN Litere.Cuvant(c)
  END Cuv;

  (* forma mica, fara diacritice, doar [a-z0-9 -], spatiile stranse *)
  PROCEDURE Norm(s: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR t: ARRAY 4096 OF CHAR; i, j: INTEGER; c: CHAR; sp: BOOLEAN;
  BEGIN Litere.Copy(s, t); Litere.MicFold(t); i := 0; j := 0; sp := FALSE;
    WHILE t[i] # 0X DO
      c := t[i];
      IF ~((c >= "a") & (c <= "z") OR (c >= "0") & (c <= "9") OR (c = "-")) THEN c := " " END ;
      IF c = " " THEN sp := TRUE
      ELSE IF sp & (j > 0) THEN d[j] := " "; INC(j) END ; sp := FALSE; d[j] := c; INC(j)
      END ;
      INC(i)
    END ;
    d[j] := 0X
  END Norm;

  PROCEDURE Cap(VAR s: ARRAY OF CHAR);
    VAR o: INTEGER;
  BEGIN o := ORD(s[0]);
    IF (o >= 61H) & (o <= 7AH) OR (o >= 0E0H) & (o <= 0FEH) & (o # 0F7H) THEN o := o - 20H
    ELSIF (o >= 100H) & (o <= 17FH) & ODD(o) OR (o = 219H) OR (o = 21BH) THEN o := o - 1
    END ;
    s[0] := CHR(o)
  END Cap;

  (* q incepe cu una din alternative urmata de sfarsit sau de un semn care nu e de cuvant? *)
  PROCEDURE Incepe(q, lista: ARRAY OF CHAR): BOOLEAN;
    VAR i, j, n: INTEGER; w: ARRAY 64 OF CHAR; r: BOOLEAN;
  BEGIN r := FALSE; i := 0;
    WHILE ~r & (lista[i] # 0X) DO
      j := 0; WHILE (lista[i] # 0X) & (lista[i] # "|") DO w[j] := lista[i]; INC(i); INC(j) END ;
      w[j] := 0X; IF lista[i] = "|" THEN INC(i) END ;
      n := Litere.Len(w);
      r := Litere.Incepe(q, w) & ((q[n] = 0X) OR ~Cuv(q[n]))
    END ;
    RETURN r
  END Incepe;

  (* q e exact una din alternative, urmata eventual de una din cozi *)
  PROCEDURE Exact(q, lista, cozi: ARRAY OF CHAR): BOOLEAN;
    VAR i, j, k, l: INTEGER; w, c: ARRAY 64 OF CHAR; x: ARRAY 160 OF CHAR; r: BOOLEAN;
  BEGIN r := FALSE; i := 0;
    WHILE ~r & (lista[i] # 0X) DO
      j := 0; WHILE (lista[i] # 0X) & (lista[i] # "|") DO w[j] := lista[i]; INC(i); INC(j) END ;
      w[j] := 0X; IF lista[i] = "|" THEN INC(i) END ;
      r := q = w; k := 0;
      WHILE ~r & (cozi[k] # 0X) DO
        l := 0; WHILE (cozi[k] # 0X) & (cozi[k] # "|") DO c[l] := cozi[k]; INC(k); INC(l) END ;
        c[l] := 0X; IF cozi[k] = "|" THEN INC(k) END ;
        Litere.Copy(w, x); Litere.Add(x, c); r := q = x
      END
    END ;
    RETURN r
  END Exact;

  PROCEDURE Intrebare(q: ARRAY OF CHAR): BOOLEAN;
  BEGIN RETURN Incepe(q, "ce|cine|cum|cand|unde|de ce|cat|cati|cate|care|oare|poti|stii|ai|esti|exista|arata|regula|verifica")
  END Intrebare;

  PROCEDURE LitNume(c: CHAR): BOOLEAN;   (* [\p{L}-] *)
  BEGIN RETURN Litere.Litera(c) OR (c = "-")
  END LitNume;

  PROCEDURE SpatiuJ(c: CHAR): BOOLEAN;
  BEGIN RETURN (c = " ") OR (c = 9X) OR (c = 0AX) OR (c = 0BX) OR (c = 0CX) OR (c = 0DX)
  END SpatiuJ;

  (* dupa unul din prefixe (in forma fara diacritice, mica), \s+, un nume \p{L}[\p{L}-]{1,30}, apoi doar [\s.!] *)
  PROCEDURE DupaPrefix(raw, prefixe: ARRAY OF CHAR; VAR d: ARRAY OF CHAR): BOOLEAN;
    VAR f: ARRAY 4096 OF CHAR; i, j, n, a, b: INTEGER; w: ARRAY 64 OF CHAR; r: BOOLEAN;
  BEGIN Litere.Copy(raw, f); Litere.MicFold(f); n := Litere.Len(f); r := FALSE; i := 0;
    WHILE ~r & (prefixe[i] # 0X) DO
      j := 0; WHILE (prefixe[i] # 0X) & (prefixe[i] # "|") DO w[j] := prefixe[i]; INC(i); INC(j) END ;
      w[j] := 0X; IF prefixe[i] = "|" THEN INC(i) END ;
      IF Litere.Incepe(f, w) THEN
        a := Litere.Len(w);
        IF (a < n) & SpatiuJ(f[a]) THEN
          WHILE (a < n) & SpatiuJ(f[a]) DO INC(a) END ;
          b := a;
          IF (b < n) & Litere.Litera(raw[b]) THEN
            INC(b); WHILE (b < n) & LitNume(raw[b]) DO INC(b) END ;
            IF (b - a >= 2) & (b - a <= 31) THEN
              j := b; WHILE (j < n) & (SpatiuJ(raw[j]) OR (raw[j] = ".") OR (raw[j] = "!")) DO INC(j) END ;
              IF j = n THEN Litere.Sub(raw, a, b, d); Cap(d); r := TRUE END
            END
          END
        END
      END
    END ;
    RETURN r
  END DupaPrefix;

  PROCEDURE NumeDin(raw: ARRAY OF CHAR; VAR d: ARRAY OF CHAR): BOOLEAN;
    VAR r: BOOLEAN; n, a, b, j: INTEGER;
  BEGIN r := DupaPrefix(raw, "ma numesc|numele meu este|numele meu e|ma cheama", d);
    IF ~r & ((raw[0] = "E") OR (raw[0] = "e")) & (raw[1] = "u") & (raw[2] = " ") & (raw[3] = "s") & (raw[4] = "u") & (raw[5] = "n") & (raw[6] = "t") THEN
      n := Litere.Len(raw); a := 7;
      IF (a < n) & SpatiuJ(raw[a]) THEN
        WHILE (a < n) & SpatiuJ(raw[a]) DO INC(a) END ;
        IF (a < n) & Litere.Mare(raw[a]) THEN
          b := a + 1; WHILE (b < n) & LitNume(raw[b]) DO INC(b) END ;
          IF (b - a >= 2) & (b - a <= 31) THEN
            j := b; WHILE (j < n) & (SpatiuJ(raw[j]) OR (raw[j] = ".") OR (raw[j] = "!")) DO INC(j) END ;
            IF j = n THEN Litere.Sub(raw, a, b, d); Cap(d); r := TRUE END
          END
        END
      END
    END ;
    RETURN r
  END NumeDin;

  (* salutul de la inceput; intoarce unde se termina (sau -1) *)
  PROCEDURE Salut(raw: ARRAY OF CHAR): INTEGER;
    VAR f: ARRAY 4096 OF CHAR; i, j, n, a, e, res: INTEGER; w: ARRAY 32 OF CHAR; lista: ARRAY 160 OF CHAR;

    PROCEDURE Sare(VAR f: ARRAY OF CHAR; i, n: INTEGER): INTEGER;   (* [\s,!.]* *)
    BEGIN WHILE (i < n) & (SpatiuJ(f[i]) OR (f[i] = ",") OR (f[i] = "!") OR (f[i] = ".")) DO INC(i) END ;
      RETURN i
    END Sare;

  BEGIN Litere.Copy(raw, f); Litere.MicFold(f); n := Litere.Len(f); res := -1;
    lista := "salut|salutare|buna ziua|buna dimineata|buna seara|buna|hei|hey|neata|servus|ceau|ciao|hello";
    a := 0; WHILE (a < n) & SpatiuJ(f[a]) DO INC(a) END ;
    i := 0;
    WHILE (res < 0) & (lista[i] # 0X) DO
      j := 0; WHILE (lista[i] # 0X) & (lista[i] # "|") DO w[j] := lista[i]; INC(i); INC(j) END ;
      w[j] := 0X; IF lista[i] = "|" THEN INC(i) END ;
      e := a; j := 0;
      WHILE (w[j] # 0X) & (e < n) & (f[e] = w[j]) DO INC(e); INC(j) END ;
      IF (w[j] = 0X) & ((e = n) OR ~Cuv(f[e])) THEN
        e := Sare(f, e, n);
        IF (e + 4 <= n) & (f[e] = "e") & (f[e+1] = "u") & (f[e+2] = "l") & (f[e+3] = "a") & ((e + 4 = n) OR ~Cuv(f[e+4])) THEN
          j := e + 4; WHILE (j < n) & SpatiuJ(f[j]) DO INC(j) END ;
          IF (j + 6 <= n) & (f[j] = "o") & (f[j+1] = "b") & (f[j+2] = "e") & (f[j+3] = "r") & (f[j+4] = "o") & (f[j+5] = "n") & ((j + 6 = n) OR ~Cuv(f[j+6])) THEN
            e := j + 6
          ELSE e := e + 4
          END
        END ;
        res := Sare(f, e, n)
      END
    END ;
    RETURN res
  END Salut;

  PROCEDURE NumeRaspuns(raw: ARRAY OF CHAR; VAR d: ARRAY OF CHAR): BOOLEAN;
    VAR r: BOOLEAN; n, b, j, cuv: INTEGER; nn, nr: ARRAY 4096 OF CHAR; sp: BOOLEAN;
  BEGIN r := FALSE;
    IF Salut(raw) < 0 THEN
      r := NumeDin(raw, d);
      IF ~r THEN r := DupaPrefix(raw, "spune-mi|spune mi|poti sa-mi spui|poti sa imi spui|imi poti spune|zi-mi|zi mi", d) END ;
      IF ~r & Litere.Litera(raw[0]) THEN
        n := Litere.Len(raw); b := 1;
        WHILE (b < n) & LitNume(raw[b]) DO INC(b) END ;
        IF (b >= 2) & (b <= 31) & ((b = n) OR (SpatiuJ(raw[b]) OR (raw[b] = ",") OR (raw[b] = ".") OR (raw[b] = "!")) & (n - b - 1 <= 60)) THEN
          Litere.Sub(raw, 0, b, d);
          cuv := 0; sp := TRUE; j := 0;                      (* raw.split("\\s+").length *)
          WHILE j < n DO IF SpatiuJ(raw[j]) THEN sp := TRUE ELSIF sp THEN INC(cuv); sp := FALSE END ; INC(j) END ;
          Norm(d, nn); Norm(raw, nr);
          r := (cuv <= 8) & ~Litere.Stop(nn) & (nn # "eula") & ~Intrebare(nr);
          IF r THEN                                          (* nu „WriteString” si nu „ABC” *)
            j := 1; WHILE (d[j] >= "a") & (d[j] <= "z") DO INC(j) END ;
            IF (d[0] >= "A") & (d[0] <= "Z") & (d[j] >= "A") & (d[j] <= "Z") THEN r := FALSE END ;
            j := 0; WHILE (d[j] >= "A") & (d[j] <= "Z") DO INC(j) END ;
            IF (j > 0) & (d[j] = 0X) THEN r := FALSE END
          END ;
          IF r THEN Cap(d) END
        END
      END
    END ;
    RETURN r
  END NumeRaspuns;

  (* „X este …” spus, nu intrebat *)
  PROCEDURE Invata(raw: ARRAY OF CHAR): BOOLEAN;
    VAR t: ARRAY 4096 OF CHAR; n, i, k, a, b: INTEGER; r, bun: BOOLEAN; w: ARRAY 64 OF CHAR;

    PROCEDURE Copula(w: ARRAY OF CHAR): BOOLEAN;
    BEGIN RETURN (w = "este") OR (w = "e") OR (w = "sunt") OR (w = "inseamna") OR (w = "înseamnă") OR (w = "reprezinta") OR (w = "reprezintă")
    END Copula;

  BEGIN Litere.Copy(raw, t); Litere.Trim(t); n := Litere.Len(t);
    WHILE (n > 0) & ((t[n-1] = ".") OR (t[n-1] = "!")) DO DEC(n); t[n] := 0X END ;
    r := FALSE; k := 1;
    WHILE ~r & (k <= 3) DO
      i := 0; bun := TRUE; a := 0;
      WHILE bun & (a < k) DO                                (* k cuvinte, despartite de cate un spatiu *)
        b := i;
        WHILE (b < n) & (Litere.Litera(t[b]) OR (t[b] = "-") OR (a = 0) & ((t[b] = ".") OR (t[b] = "_"))) DO INC(b) END ;
        bun := (b - i >= 2) & (b - i <= 40) & (b < n) & (t[b] = " ");
        i := b + 1; INC(a)
      END ;
      IF bun THEN
        b := i; WHILE (b < n) & (t[b] # " ") DO INC(b) END ;
        Litere.Sub(t, i, b, w);
        r := Copula(w) & (b < n) & (n - b - 1 >= 6)
      END ;
      INC(k)
    END ;
    RETURN r
  END Invata;

  PROCEDURE Stare;
  BEGIN
    S("Am mâncat "); Iesire.Cate(Memorie.nrec, "fișier", "fișiere"); S(": "); Iesire.Cate(Memorie.NrModule(), "modul", "module"); S(", ");
    Iesire.Cate(Memorie.NrProceduri(), "procedură", "proceduri"); S(", "); Iesire.Cate(Memorie.NrLinii(), "rând", "rânduri");
    S(" de cod ("); Iesire.Cate(Memorie.T, "semn", "semne"); S("), tăiate în "); Iesire.Cate(Memorie.nu, "unitate", "unități"); S(". ");
    IF intrebari > 0 THEN
      S("M-ai întrebat "); IF intrebari = 1 THEN S("o dată") ELSE S("de "); Iesire.Cate(intrebari, "dată", "ori") END ;
      S("; "); IF nustiu = 1 THEN S("o dată") ELSE S("de "); Iesire.Cate(nustiu, "dată", "ori") END ; S(" n-am știut sigur. ")
    END ;
    IF verificate > 0 THEN S("Am verificat "); Iesire.Cate(verificate, "bucată", "bucăți"); S(" de cod. ") END ;
    IF invatate > 0 THEN S("De la tine am învățat "); Iesire.Int(invatate); IF invatate = 1 THEN S(" lucru.") ELSE S(" lucruri.") END END
  END Stare;

  PROCEDURE NumeNou(n: ARRAY OF CHAR; s: INTEGER);
    VAR k: INTEGER;
  BEGIN Litere.Copy(n, nume); areNume := TRUE; Salveaza; k := Pick(s, 3);
    IF k = 0 THEN S("Încântată, "); S(nume); S(". Te țin minte.")
    ELSIF k = 1 THEN S("Bine, "); S(nume); S(". De acum știu cum te cheamă.")
    ELSE S(nume); S(", notat.")
    END
  END NumeNou;

  PROCEDURE Despre(q, raw: ARRAY OF CHAR; s: INTEGER): INTEGER;
    VAR r, i, j, f, k: INTEGER; n: ARRAY 64 OF CHAR; t: ARRAY 4096 OF CHAR;
  BEGIN r := 1;
    (* Roler peste Cubicum FS *)
    i := 0;
    IF Litere.Incepe(q, "striga ") THEN i := 7 ELSIF Litere.Incepe(q, "cheama ") THEN i := 7 ELSIF Litere.Incepe(q, "suna ") THEN i := 5 END ;
    j := i; f := 0;
    WHILE (i > 0) & (q[j] >= "0") & (q[j] <= "9") DO f := f * 10 + ORD(q[j]) - ORD("0"); INC(j) END ;
    IF (i > 0) & (j > i) & ((q[j] = 0X) OR (q[j] = " ") & (q[j+1] = "h") & (q[j+2] = "z") & (q[j+3] = 0X) OR (q[j] = "h") & (q[j+1] = "z") & (q[j+2] = 0X)) THEN
      Roler.Striga(f)
    ELSIF Exact(q, "ce suna cu asta|ce suna cu raspunsul|ce rezoneaza cu asta|ce suna cu el|cu ce suna", "") THEN Roler.SunaCu(Motor.ultimRec)
    ELSIF Exact(q, "harta fisierelor|harta memoriei|ce fisiere ai|unde stau fisierele|cubul fisierelor", "") THEN Roler.Rezumat
    ELSE
      Litere.Copy(raw, t); Litere.Trim(t);
      IF NumeDin(t, n) THEN NumeNou(n, s)
      ELSIF Incepe(q, "cum ma cheama|stii cine sunt|cine sunt eu|stii cum ma cheama") THEN
        IF areNume THEN IF Pick(s, 2) = 0 THEN S("Te cheamă "); S(nume); S(".") ELSE S("Ești "); S(nume); S(".") END
        ELSE S("Nu mi-ai spus încă. Scrie „mă numesc …”.")
        END
      ELSIF Incepe(q, "cine esti|ce esti|poti sa te prezinti|prezinta-te|prezinta te|spune-mi despre tine|spune-mi ceva despre tine|spune mi despre tine|spune mi ceva despre tine|cine e eula|cine este eula") THEN
        S("Sunt Eula Oberon, sora Eulei 7. Știu doar Oberon: sintaxa din raportul lui Wirth și codul pe care l-am mâncat — ");
        Iesire.Cate(Memorie.NrModule(), "modul", "module"); S(", "); Iesire.Cate(Memorie.NrProceduri(), "procedură", "proceduri");
        S(". M-a făcut Pion, la Jahbalon Research, în Iași. Încă nu scriu programe; le citesc, le găsesc și le verific. ");
        S("Acum sunt scrisă chiar în Oberon: doar ecranul meu e în Java.")
      ELSIF Incepe(q, "cine te-a facut|cine te a facut|cine te-a creat|cine te a creat|cine e creatorul tau|cine e pion|cine este pion") THEN
        S("Pion, adică Ion Paraschiv, de la Jahbalon Research, din Iași. Sorobanul cu piatra soarelui, Opal și Roler sunt ideile lui, ");
        S("luate din Eula 7. Codul l-a scris împreună cu Claude. Limbajul pe care îl știu e al lui Niklaus Wirth.")
      ELSIF Incepe(q, "ce stii sa faci|ce poti face|ce poti|la ce esti buna|ajutor|help|comenzi") THEN
        S("Știu doar Oberon. Mă poți întreba:"); Iesire.C(0AX);
        S("· „ce face Texts.WriteString?”, „ce este WHILE?”, „ce este Files?”"); Iesire.C(0AX);
        S("· „arată Texts.Scan” — tot codul"); Iesire.C(0AX);
        S("· „cum folosesc Files.Old?” — exemple din cod"); Iesire.C(0AX);
        S("· „cine folosește Fonts.This?”, „unde e definit Rider?”"); Iesire.C(0AX);
        S("· „ce importă ORP?”, „cine importă Texts?”, „ce exportă Files?”, „ce module știi?”"); Iesire.C(0AX);
        S("· „regula IfStatement”, „regula” — sintaxa din raport"); Iesire.C(0AX);
        S("· orice întrebare în română: „cum deschid un fișier?”"); Iesire.C(0AX);
        S("· „lecții” — te învăț Oberon de la nivelul -1, cu exerciții pe care ți le verific"); Iesire.C(0AX);
        S("Verifică: lipește cod în căsuță și apasă Verifică — îți spun dacă trece gramatica Oberon-07."); Iesire.C(0AX);
        S("Rulează: un modul întreg îl compilez cu oberonc și îl pornesc; ce scrie Out apare aici. Cât rulează, butonul devine Oprește."); Iesire.C(0AX);
        S("Feed îmi dă cod sau text de mâncare, Importă un fișier .Mod întreg.")
      ELSIF Incepe(q, "cum functionezi|cum gandesti|cum lucrezi|cum raspunzi|cum gasesti") THEN
        S("Gramatica Oberon (regulile din raportul lui Wirth, scrise în cod) taie fiecare fișier în unități: antetul modulului, tipuri, ");
        S("constante, variabile, proceduri. Întrebările precise merg direct în tabelele ei. La celelalte, fiecare cuvânt intră printr-un colț ");
        S("al sorobanului cu 7 dimensiuni și lasă o urmă; caut unitățile cu urma cea mai apropiată, iar Opal le verifică pe 1·3·5·7·11: ");
        S("cuvintele, urma, felul cerut, dacă trec gramatica și dacă vecinii lor vorbesc despre același lucru. Trec doar cele cu 3 din 5.")
      ELSIF Incepe(q, "esti vie|esti viu|traiesti|ai constiinta|esti constienta|ai sentimente|simti ceva|esti om|esti robot|ai suflet") THEN
        IF Pick(s, 2) = 0 THEN S("Sunt un cub care citește module Oberon. Dacă asta e viață, n-aș ști să-ți spun.")
        ELSE S("Nu simt, sau n-am cum să știu că simt. Am module, o gramatică și pe Opal, care mă oprește când nu știu.")
        END
      ELSIF Exact(q, "ce faci|cum esti|cum te simti|ce mai faci|cat stii|ce ai mancat|cat de mare esti|cat ai mancat", " eula| eula oberon| tu") THEN Stare
      ELSIF Incepe(q, "cand te-ai nascut|cand te ai nascut|cati ani ai|cand ai aparut|de cand existi") THEN
        S("Eula Oberon s-a născut pe "); S(NASTERE); S(", la câteva ore după Eula 7. Oberon e mai bătrân: 1987.")
      ELSIF Exact(q, "multumesc|mersi|merci|multumesc frumos|mersi mult|bravo|felicitari", " eula| eula oberon| mult| frumos") THEN
        k := Pick(s, 3);
        IF k = 0 THEN S("Cu plăcere"); Tu; S(".") ELSIF k = 1 THEN S("Mă bucur că a folosit.") ELSE S("Cu drag.") END
      ELSIF Exact(q, "pa|la revedere|noapte buna|pe curand|ne auzim|bye", " eula| eula oberon") THEN
        k := Pick(s, 3);
        IF k = 0 THEN S("Pa"); Tu; S(". Rămân printre module.") ELSIF k = 1 THEN S("La revedere"); Tu; S(".") ELSE S("END Eula.") END
      ELSIF Litere.Incepe(q, "ce crezi despre ") OR Litere.Incepe(q, "ce parere ai despre ") OR Litere.Incepe(q, "care e parerea ta despre ") OR Litere.Incepe(q, "tu ce crezi despre ") THEN
        IF Litere.Incepe(q, "ce crezi despre ") THEN i := 16 ELSIF Litere.Incepe(q, "ce parere ai despre ") THEN i := 20
        ELSIF Litere.Incepe(q, "care e parerea ta despre ") THEN i := 25 ELSE i := 19 END ;
        Litere.Sub(q, i, Litere.Len(q), t);
        S("N-am păreri, am doar cod. Iată ce știu despre "); S(t); S(":");
        rest := "ce este "; Litere.Add(rest, t); r := 2
      ELSE
        Litere.Copy(raw, t); Litere.Trim(t);
        IF ~Litere.Sfarsit(t, "?") & ~Intrebare(q) & Invata(raw) THEN r := 3 ELSE r := 0 END
      END
    END ;
    RETURN r
  END Despre;

  PROCEDURE Raspunde*(raw: ARRAY OF CHAR): INTEGER;
    VAR q, rr, rq: ARRAY 4096 OF CHAR; n: ARRAY 64 OF CHAR; s, r, e, k, poz: INTEGER; asteptam: BOOLEAN;
  BEGIN Norm(raw, q); rest[0] := 0X; r := 0;
    IF q[0] # 0X THEN
      s := Litere.Seed(q); asteptam := astept; astept := FALSE;
      Litere.Copy(raw, rr); Litere.Trim(rr);
      IF asteptam & NumeRaspuns(rr, n) THEN NumeNou(n, s); r := 1
      ELSE
        e := Salut(raw);
        IF e >= 0 THEN
          Litere.Sub(raw, e, Litere.Len(raw), rr); Litere.Trim(rr); Norm(rr, rq);
          k := Pick(s, 3);
          IF k = 0 THEN S("Salut"); Tu; S("!") ELSIF k = 1 THEN S("Bună"); Tu; S("!") ELSE S("Salut"); Tu; S(". Sunt aici, printre module.") END ;
          IF rq[0] = 0X THEN
            astept := ~areNume;
            IF ~areNume THEN S(" Eu sunt Eula Oberon. Tu cum te cheamă?") END ;
            r := 1
          ELSE
            poz := Iesire.n; S(" ");
            r := Despre(rq, rr, Litere.Seed(rq));
            IF (r = 0) OR (r = 3) THEN Iesire.Inapoi(poz); Litere.Copy(rr, rest); r := 2 END
          END
        ELSE r := Despre(q, raw, s)
        END
      END
    END ;
    RETURN r
  END Raspunde;

  PROCEDURE Cere*(w: ARRAY OF CHAR);   (* tine minte un cuvant pe care nu l-a stiut *)
    VAR i: INTEGER; exista: BOOLEAN;
  BEGIN exista := FALSE; i := 0;
    WHILE ~exista & (i < ncer) DO exista := cerute[i] = w; INC(i) END ;
    IF ~exista & (ncer < MaxC) THEN Litere.Copy(w, cerute[ncer]); INC(ncer) END
  END Cere;

  (* dupa o intrebare la care a raspuns motorul *)
  PROCEDURE Socoteste*;
    VAR i: INTEGER;
  BEGIN INC(intrebari); IF ~Motor.sigur THEN INC(nustiu) END ;
    FOR i := 0 TO Motor.nnec - 1 DO Cere(Motor.nec[i]) END ;
    Salveaza
  END Socoteste;

  PROCEDURE Verificat*;
  BEGIN INC(verificate); Salveaza
  END Verificat;

  PROCEDURE AInvatat*(fraza: ARRAY OF CHAR);
    VAR x, c, prim: ARRAY 4096 OF CHAR; i, j: INTEGER; gasit: BOOLEAN;
  BEGIN INC(invatate);
    i := 0; WHILE (fraza[i] # 0X) & (fraza[i] # " ") DO prim[i] := fraza[i]; INC(i) END ; prim[i] := 0X;
    Norm(prim, x); gasit := FALSE; i := 0;
    WHILE ~gasit & (i < ncer) DO
      Norm(cerute[i], c);
      IF c = x THEN gasit := TRUE; FOR j := i TO ncer - 2 DO cerute[j] := cerute[j+1] END ; DEC(ncer) ELSE INC(i) END
    END ;
    Salveaza;
    IF gasit THEN S("Mulțumesc! Asta îmi lipsea: am ținut minte.")
    ELSE i := Pick(Litere.Seed(fraza), 3);
      IF i = 0 THEN S("Am ținut minte.") ELSIF i = 1 THEN S("Notat printre module.") ELSE S("Bine, acum știu.") END
    END
  END AInvatat;

BEGIN areNume := FALSE; nume := ""; intrebari := 0; nustiu := 0; invatate := 0; verificate := 0; ncer := 0; astept := FALSE; cale := ""
END Fire.
