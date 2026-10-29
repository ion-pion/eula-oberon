MODULE Motor; (* Eula Oberon: motorul. Intrebarile precise (ce face X, arata X, cum folosesc X, cine importa M,
  regula X) merg direct in tabelele gramaticii. Restul merge ca in Eula 7: candidatele dupa cuvinte, sorobanul 7D
  le aseaza, Opal verifica 1·3·5·7·11 (cuvintele, urma, felul cerut, trece gramatica, vecinii) si lasa sa treaca
  doar ce trece 3 din 5. *)

  IMPORT Litere, Iesire, Gramatica, Memorie, Soroban7, Raport, Roler, Math;

  CONST
    POOL = 120; OPALN = 7; OPALPRAG = 3; MAXRANDURI = 40;
    MaxU = Memorie.MaxU; MaxL = 8192; MaxGr = 32; MaxGi = 512; MaxNec* = 16;
    KModul = 0; KConst = 1; KType = 2; KVar = 3; KProc = 4; KCorp = 5; KText = 6;
    ORICE = 0; PROC = 1; TIP = 2; CONSTANTA = 3; VARIABILA = 4; MODUL = 5; TEXT = 6;

  TYPE Sir = ARRAY 256 OF CHAR;

  VAR
    ultimRec*: INTEGER; sigur*: BOOLEAN;
    nota*: ARRAY 2048 OF CHAR;
    nnec*: INTEGER; nec*: ARRAY MaxNec OF ARRAY 64 OF CHAR;   (* cuvintele pe care nu le-a intalnit *)
    felDecl, fel, rolNume: ARRAY 7 OF ARRAY 24 OF CHAR;
    umplutura: ARRAY 24 OF ARRAY 16 OF CHAR; numpl: INTEGER;
    lm, ld, lu, lx: ARRAY 8192 OF INTEGER;                     (* liste de lucru *)
    siruri: ARRAY 1024 OF Sir; nsir: INTEGER;                  (* liste de nume de lucru *)
    (* cautarea *)
    scor, best: ARRAY MaxU OF REAL;
    scStamp, bStamp, sorSc: ARRAY MaxU OF INTEGER; stampQ, stampG: INTEGER;
    cand, glist: ARRAY MaxU OF INTEGER; ncand, nglist: INTEGER;
    tmpI: ARRAY MaxU OF INTEGER; tmpR: ARRAY MaxU OF REAL;
    gA, gN: ARRAY MaxGr OF INTEGER; gIds: ARRAY MaxGi OF INTEGER; ngr, ngi: INTEGER;
    toate: ARRAY MaxGi OF INTEGER; ntoate: INTEGER;
    linie: ARRAY 4096 OF CHAR;

  (* ---------- mici ajutoare ---------- *)

  PROCEDURE S(s: ARRAY OF CHAR); BEGIN Iesire.S(s) END S;
  PROCEDURE C(c: CHAR); BEGIN Iesire.C(c) END C;
  PROCEDURE Ln; BEGIN Iesire.C(0AX) END Ln;

  PROCEDURE Nota(s: ARRAY OF CHAR); BEGIN Litere.Copy(s, nota) END Nota;
  PROCEDURE NotaA(s: ARRAY OF CHAR); BEGIN Litere.Add(nota, s) END NotaA;

  PROCEDURE NecAre(w: ARRAY OF CHAR): BOOLEAN;
    VAR i: INTEGER; r: BOOLEAN;
  BEGIN r := FALSE; i := 0;
    WHILE ~r & (i < nnec) DO r := nec[i] = w; INC(i) END ;
    RETURN r
  END NecAre;

  PROCEDURE NecPune(w: ARRAY OF CHAR);
  BEGIN IF nnec < MaxNec THEN Litere.Copy(w, nec[nnec]); INC(nnec) END
  END NecPune;

  PROCEDURE ModIn(r: INTEGER; VAR d: ARRAY OF CHAR); BEGIN Memorie.ModIn(r, d) END ModIn;
  PROCEDURE SrcIn(r: INTEGER; VAR d: ARRAY OF CHAR); BEGIN Memorie.SrcIn(r, d) END SrcIn;

  PROCEDURE SModul(r: INTEGER);   (* scrie numele modulului (sau „null”, ca in Java, cand nu e) *)
    VAR m: Sir;
  BEGIN ModIn(r, m); IF m[0] # 0X THEN S(m) ELSE S("null") END
  END SModul;

  PROCEDURE SSrc(r: INTEGER);
    VAR m: ARRAY 600 OF CHAR;
  BEGIN SrcIn(r, m); S(m)
  END SSrc;

  PROCEDURE NotaSrc(r: INTEGER);
    VAR m: ARRAY 600 OF CHAR;
  BEGIN SrcIn(r, m); NotaA(m)
  END NotaSrc;

  PROCEDURE NotaNod(r: INTEGER);
    VAR d: ARRAY 300 OF CHAR;
  BEGIN d := ""; Roler.NodIn(r, d); NotaA(d)
  END NotaNod;

  (* textul [a, b) din fisierul r in bucata de lucru *)
  PROCEDURE TText(r, a, b: INTEGER);
  BEGIN Iesire.TGol; WHILE a < b DO Iesire.TC(Memorie.RCh(r, a)); INC(a) END
  END TText;


  PROCEDURE Linii(r, a, b: INTEGER): INTEGER;
    VAR k: INTEGER;
  BEGIN k := 1; WHILE a < b DO IF Memorie.RCh(r, a) = 0AX THEN INC(k) END ; INC(a) END ;
    RETURN k
  END Linii;

  PROCEDURE DeLaR(r, a, b: INTEGER; VAR d: ARRAY OF CHAR);   (* textul [a, b) din fisierul r *)
    VAR j: INTEGER;
  BEGIN j := 0;
    WHILE (a < b) & (j < LEN(d) - 1) DO d[j] := Memorie.RCh(r, a); INC(a); INC(j) END ;
    d[j] := 0X
  END DeLaR;

  (* cauta p in fisierul r de la pozitia de incolo (pana la lim); -1 daca nu e *)
  PROCEDURE IndexR(r: INTEGER; p: ARRAY OF CHAR; de, lim: INTEGER): INTEGER;
    VAR i, j, n, res: INTEGER;
  BEGIN n := Litere.Len(p); res := -1; i := de;
    WHILE (res < 0) & (i + n <= lim) DO
      j := 0; WHILE (j < n) & (Memorie.RCh(r, i + j) = p[j]) DO INC(j) END ;
      IF j = n THEN res := i END ;
      INC(i)
    END ;
    RETURN res
  END IndexR;

  PROCEDURE Spatiu(c: CHAR): BOOLEAN;
  BEGIN RETURN (c = " ") OR (c = 9X) OR (c = 0AX) OR (c = 0BX) OR (c = 0CX) OR (c = 0DX)
  END Spatiu;

  (* spatiile multiple devin unul singur, iar capetele se curata *)
  PROCEDURE Strange(VAR s: ARRAY OF CHAR);
    VAR i, j: INTEGER; sp: BOOLEAN;
  BEGIN i := 0; j := 0; sp := FALSE;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO
      IF Spatiu(s[i]) THEN sp := TRUE ELSE IF sp & (j > 0) THEN s[j] := " "; INC(j) END ; sp := FALSE; s[j] := s[i]; INC(j) END ;
      INC(i)
    END ;
    s[j] := 0X
  END Strange;

  PROCEDURE SirePune(s: ARRAY OF CHAR): BOOLEAN;   (* adauga in lista de nume, daca nu e deja; TRUE daca a adaugat *)
    VAR i: INTEGER; r: BOOLEAN;
  BEGIN r := TRUE; i := 0;
    WHILE r & (i < nsir) DO IF siruri[i] = s THEN r := FALSE END ; INC(i) END ;
    IF r & (nsir < LEN(siruri)) THEN Litere.Copy(s, siruri[nsir]); INC(nsir) ELSE r := FALSE END ;
    RETURN r
  END SirePune;

  PROCEDURE SJoin(n, max: INTEGER);   (* scrie primele max din lista de nume, despartite de virgula *)
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < n) & (i < max) DO IF i > 0 THEN S(", ") END ; S(siruri[i]); INC(i) END
  END SJoin;

  PROCEDURE MicEq(a, b: ARRAY OF CHAR): BOOLEAN;   (* equalsIgnoreCase *)
    VAR x, y: Sir;
  BEGIN Litere.Copy(a, x); Litere.MicS(x); Litere.Copy(b, y); Litere.MicS(y);
    RETURN x = y
  END MicEq;

  PROCEDURE MicLess(a, b: ARRAY OF CHAR): BOOLEAN;   (* CASE_INSENSITIVE_ORDER *)
    VAR x, y: Sir;
  BEGIN Litere.Copy(a, x); Litere.MicS(x); Litere.Copy(b, y); Litere.MicS(y);
    RETURN x < y
  END MicLess;

  PROCEDURE Pick(seed, n: INTEGER): INTEGER;
  BEGIN RETURN seed MOD n
  END Pick;

  (* ---------- vorbele ei (din Fire, aici ca sa le poata folosi si motorul) ---------- *)

  PROCEDURE NuStiu*(seed: INTEGER);
    VAR k: INTEGER;
  BEGIN k := Pick(seed, 5);
    IF k <= 2 THEN S("Nu știu sigur.") ELSIF k = 3 THEN S("Piatra soarelui n-a vrut să sară: nu știu sigur.")
    ELSE S("Opal m-a oprit, deci nu știu sigur.")
    END
  END NuStiu;

  PROCEDURE Curios*(w: ARRAY OF CHAR; seed: INTEGER);
    VAR k: INTEGER;
  BEGIN k := Pick(seed, 3);
    IF k = 0 THEN S("N-am dat niciodată de „"); S(w); S("” în Oberon. Ce e?")
    ELSIF k = 1 THEN S("Ce e „"); S(w); S("”? Nu l-am întâlnit în codul meu.")
    ELSE S("Nume nou pentru mine: „"); S(w); S("”. Mi-l arăți?")
    END ;
    S(" Dacă e un modul, dă-mi-l cu Importă; dacă e altceva, scrie „"); S(w); S(" este …” și țin minte.")
  END Curios;

  (* ---------- intrebarea ---------- *)

  PROCEDURE Lit(c: CHAR): BOOLEAN;
  BEGIN RETURN (c >= "A") & (c <= "Z") OR (c >= "a") & (c <= "z") OR (c = "_")
  END Lit;

  PROCEDURE LitCif(c: CHAR): BOOLEAN;
  BEGIN RETURN Lit(c) OR (c >= "0") & (c <= "9")
  END LitCif;

  (* s e un singur NUME (ident sau Modul.ident)? *)
  PROCEDURE EsteNume(s: ARRAY OF CHAR): BOOLEAN;
    VAR i: INTEGER; r: BOOLEAN;
  BEGIN i := 0; r := Lit(s[0]);
    IF r THEN
      WHILE LitCif(s[i]) DO INC(i) END ;
      IF s[i] = "." THEN INC(i); r := Lit(s[i]); WHILE LitCif(s[i]) DO INC(i) END END ;
      r := r & (s[i] = 0X)
    END ;
    RETURN r
  END EsteNume;

  (* forma mica, fara diacritice, fara semne; punctele raman doar intre nume (Texts.Write) *)
  PROCEDURE Norm(raw: ARRAY OF CHAR; VAR f: ARRAY OF CHAR);
    VAR t: ARRAY 4096 OF CHAR; i, j, n: INTEGER; c: CHAR; sp: BOOLEAN;
  BEGIN Litere.Copy(raw, t); Litere.MicFold(t); n := Litere.Len(t); i := 0;
    WHILE i < n DO
      c := t[i];
      IF (ORD(c) = 201EH) OR (ORD(c) = 201DH) OR (c = 22X) OR (ORD(c) = 201CH) OR (c = "?") OR (c = "!") OR (c = ";") OR (c = ":")
        OR (c = ",") OR (ORD(c) = 0ABH) OR (ORD(c) = 0BBH) OR (c = "`") OR (c = "'") THEN t[i] := " " END ;
      INC(i)
    END ;
    j := 0; i := 0;                                          (* punctele: (?<![A-Za-z0-9_])\. | \.(?![A-Za-z_]) devin spatii *)
    WHILE i < n DO
      c := t[i];
      IF (c = ".") & ((i = 0) OR ~LitCif(t[i-1]) OR (i + 1 >= n) OR ~Lit(t[i+1])) THEN c := " " END ;
      f[j] := c; INC(j); INC(i)
    END ;
    f[j] := 0X;
    j := 0; i := 0; sp := FALSE;                             (* \s+ -> un spatiu, si trim *)
    WHILE f[i] # 0X DO
      IF Spatiu(f[i]) THEN sp := TRUE
      ELSE IF sp & (j > 0) THEN t[j] := " "; INC(j) END ; sp := FALSE; t[j] := f[i]; INC(j)
      END ;
      INC(i)
    END ;
    t[j] := 0X; Litere.Copy(t, f)
  END Norm;

  (* forma din intrebare (cu literele mari ale ei) a unui nume gasit in forma mica *)
  PROCEDURE Orig(raw, mic: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR t: ARRAY 4096 OF CHAR; w: Sir; i, a, n: INTEGER; gasit: BOOLEAN;
  BEGIN Litere.Copy(raw, t); Litere.FoldS(t); n := Litere.Len(t); i := 0; gasit := FALSE;
    WHILE ~gasit & (i < n) DO
      IF Lit(t[i]) THEN
        a := i;
        WHILE (i < n) & LitCif(t[i]) DO INC(i) END ;
        IF (i + 1 < n) & (t[i] = ".") & Lit(t[i+1]) THEN INC(i); WHILE (i < n) & LitCif(t[i]) DO INC(i) END END ;
        Litere.Sub(t, a, i, w); Litere.Copy(w, d); Litere.MicS(w);
        gasit := w = mic
      ELSE INC(i)
      END
    END ;
    IF ~gasit THEN Litere.Copy(mic, d) END
  END Orig;

  PROCEDURE EUmplutura(w: ARRAY OF CHAR): BOOLEAN;
    VAR i: INTEGER; r: BOOLEAN;
  BEGIN r := FALSE; i := 0;
    WHILE ~r & (i < numpl) DO r := umplutura[i] = w; INC(i) END ;
    RETURN r
  END EUmplutura;

  (* dupa prefix (alternative cu „|”) si un spatiu, optional unul din opt (cu spatiu dupa), apoi cuvinte de umplutura
     si la sfarsit fie un singur NUME (doarNume), fie orice rest. *)
  PROCEDURE Forma(f, pre, opt: ARRAY OF CHAR; umpl, doarNume: BOOLEAN; VAR rest: ARRAY OF CHAR): BOOLEAN;
    VAR alt, o: Sir; i, j, k, n: INTEGER; ok: BOOLEAN; r1: ARRAY 4096 OF CHAR;

    PROCEDURE Alt(lista: ARRAY OF CHAR; VAR i: INTEGER; VAR d: ARRAY OF CHAR): BOOLEAN;
      VAR j: INTEGER;
    BEGIN j := 0;
      WHILE (lista[i] # 0X) & (lista[i] # "|") DO d[j] := lista[i]; INC(i); INC(j) END ;
      d[j] := 0X; IF lista[i] = "|" THEN INC(i) END ;
      RETURN j > 0
    END Alt;

    PROCEDURE Coada(VAR r: ARRAY OF CHAR; umpl, doarNume: BOOLEAN; VAR rest: ARRAY OF CHAR): BOOLEAN;
      VAR a, b, n: INTEGER; w: Sir; gata, ok: BOOLEAN;
    BEGIN n := Litere.Len(r); a := 0; gata := FALSE;
      IF umpl THEN
        WHILE ~gata DO
          b := a; WHILE (b < n) & (r[b] # " ") DO INC(b) END ;
          IF b < n THEN Litere.Sub(r, a, b, w);
            IF EUmplutura(w) THEN a := b + 1 ELSE gata := TRUE END
          ELSE gata := TRUE
          END
        END
      END ;
      Litere.Sub(r, a, n, rest);
      IF doarNume THEN ok := EsteNume(rest) ELSE ok := rest[0] # 0X END ;
      RETURN ok
    END Coada;

  BEGIN ok := FALSE; i := 0; n := Litere.Len(f);
    WHILE ~ok & Alt(pre, i, alt) DO
      k := Litere.Len(alt);
      IF Litere.Incepe(f, alt) & (k < n) & (f[k] = " ") THEN
        Litere.Sub(f, k + 1, n, r1);
        j := 0;
        WHILE ~ok & Alt(opt, j, o) DO
          IF Litere.Incepe(r1, o) & (r1[Litere.Len(o)] = " ") THEN
            Litere.Sub(r1, Litere.Len(o) + 1, Litere.Len(r1), rest);
            ok := Coada(rest, umpl, doarNume, rest)
          END
        END ;
        IF ~ok THEN ok := Coada(r1, umpl, doarNume, rest) END
      END
    END ;
    RETURN ok
  END Forma;

  PROCEDURE Unul(f, lista: ARRAY OF CHAR): BOOLEAN;   (* f e exact una din alternative? *)
    VAR i, j: INTEGER; w: Sir; r: BOOLEAN;
  BEGIN r := FALSE; i := 0;
    WHILE ~r & (lista[i] # 0X) DO
      j := 0; WHILE (lista[i] # 0X) & (lista[i] # "|") DO w[j] := lista[i]; INC(i); INC(j) END ;
      w[j] := 0X; IF lista[i] = "|" THEN INC(i) END ;
      r := w = f
    END ;
    RETURN r
  END Unul;

  (* ---------- formatul glosarului si regulile ---------- *)

  PROCEDURE FormatGlosar(VAR g: ARRAY OF CHAR);
    VAR p: INTEGER;
  BEGIN p := 0; WHILE (g[p] # 0X) & ~((g[p] = 0AX) & (g[p+1] = 0AX)) DO INC(p) END ;
    IF g[p] = 0X THEN S(g)
    ELSE
      g[p] := 0X; S(g); Ln;
      Iesire.TGol; INC(p, 2);
      WHILE g[p] # 0X DO Iesire.TC(g[p]); INC(p) END ;
      Iesire.CodT(1000000)
    END
  END FormatGlosar;

  PROCEDURE Regula(ce: ARRAY OF CHAR);
    VAR r: ARRAY 400 OF CHAR; w, x: Sir; i, j, n: INTEGER; ok: BOOLEAN;
  BEGIN sigur := TRUE;
    IF ce[0] = 0X THEN
      S("Știu cele "); Iesire.Cate(Raport.nr, "regulă", "reguli"); S(" ale sintaxei Oberon-07, din raportul lui Wirth. Cere-mi una: ");
      FOR i := 0 TO Raport.nr - 1 DO IF i > 0 THEN S(", ") END ; Raport.RegulaNume(i, w); S(w) END ;
      S(".")
    ELSE
      j := 0; i := 0; WHILE ce[i] # 0X DO IF ce[i] # " " THEN x[j] := ce[i]; INC(j) END ; INC(i) END ; x[j] := 0X;
      ok := Raport.Regula(x, r);
      i := 0; n := Litere.Len(ce);
      WHILE ~ok & (i < n) DO
        j := i; WHILE (j < n) & (ce[j] # " ") DO INC(j) END ;
        Litere.Sub(ce, i, j, w); ok := Raport.Regula(w, r); i := j + 1
      END ;
      IF ~ok THEN sigur := FALSE; S("N-am o regulă cu numele „"); S(ce); S("”. Scrie „regula” ca să le vezi pe toate.")
      ELSE Nota("sintaxa din raportul Oberon-07"); S("Regula din raport:"); Ln; Iesire.Cod(r)
      END
    END
  END Regula;

  (* ---------- definitii ---------- *)

  PROCEDURE Imparte(nume: ARRAY OF CHAR; VAR mod, n: ARRAY OF CHAR);   (* „Texts.Write” -> „Texts”, „Write” *)
    VAR p, k: INTEGER;
  BEGIN p := 0; WHILE (nume[p] # 0X) & (nume[p] # ".") DO INC(p) END ;
    k := Litere.Len(nume);
    IF (nume[p] = ".") & (p > 0) THEN Litere.Sub(nume, 0, p, mod); Litere.Sub(nume, p + 1, k, n)
    ELSE mod[0] := 0X; Litere.Copy(nume, n)
    END
  END Imparte;

  PROCEDURE CelMaiCurat(n: INTEGER): INTEGER;   (* din lm[0..n) fisierul cu sursa cea mai curata (primul la egalitate) *)
    VAR r, i: INTEGER;
  BEGIN r := lm[0];
    FOR i := 0 TO n - 1 DO IF Memorie.recRang[lm[i]] < Memorie.recRang[r] THEN r := lm[i] END END ;
    RETURN r
  END CelMaiCurat;

  PROCEDURE PrimulComentariu(r: INTEGER; VAR d: ARRAY OF CHAR): BOOLEAN;
    VAR a, b: INTEGER; c: ARRAY 4096 OF CHAR; ok: BOOLEAN;
  BEGIN ok := FALSE; a := IndexR(r, "(*", 0, Memorie.recN[r]);
    IF (a >= 0) & (a <= 400) THEN
      b := IndexR(r, "*)", a, Memorie.recN[r]);
      IF b >= a + 2 THEN
        DeLaR(r, a + 2, b, c); Strange(c);
        IF c[0] # 0X THEN
          IF Litere.Len(c) > 200 THEN c[200] := 0X; Litere.Add(c, "…") END ;
          Litere.Copy(c, d); ok := TRUE
        END
      END
    END ;
    RETURN ok
  END PrimulComentariu;

  PROCEDURE Exportate(r: INTEGER): INTEGER;   (* numele exportate ale fisierului r, in lista de nume *)
    VAR x: INTEGER; nm: Sir; b: BOOLEAN;
  BEGIN nsir := 0;
    FOR x := 0 TO Memorie.nd - 1 DO
      IF (Memorie.dRec[x] = r) & Memorie.dExp[x] & (Memorie.dLevel[x] = 0) THEN Memorie.DNumeIn(x, nm); b := SirePune(nm) END
    END ;
    RETURN nsir
  END Exportate;

  PROCEDURE DespreModul(n: INTEGER);
    VAR r, k, i: INTEGER; m: Sir; c: ARRAY 400 OF CHAR;
  BEGIN r := CelMaiCurat(n); ultimRec := r; sigur := TRUE;
    S("Modulul "); SModul(r); S(" ("); Memorie.DialIn(r, m); S(m); S(", "); Iesire.Cate(Linii(r, 0, Memorie.recN[r]), "rând", "rânduri"); S(").");
    IF PrimulComentariu(r, c) THEN S(" Începe cu: "); S(c) END ;
    IF Memorie.recImpN[r] = 0 THEN Ln; S("Nu importă nimic.")
    ELSE Ln; S("Importă: ");
      FOR i := 0 TO Memorie.recImpN[r] - 1 DO IF i > 0 THEN S(", ") END ; Memorie.ImpIn(Memorie.recImpA[r] + i, m); S(m) END ;
      S(".")
    END ;
    k := Exportate(r);
    IF k > 0 THEN Ln; S("Exportă "); Iesire.Int(k); S(": "); SJoin(k, 25); IF k > 25 THEN S(" …") END ; S(".") END ;
    IF n > 1 THEN Ln; S("(Am "); Iesire.Cate(n, "fișier", "fișiere"); S(" cu modulul ăsta; îl arăt pe cel din "); SSrc(r); S(".)") END ;
    Nota("modul · "); NotaSrc(r); NotaA(" · "); NotaNod(r)
  END DespreModul;

  (* antetul unei proceduri: de la PROCEDURE pana la „;” de dupa parametri, plus restul randului *)
  PROCEDURE AntetProc(r, from, to: INTEGER);
    VAR depth, i, e: INTEGER; c: CHAR; gata: BOOLEAN;
  BEGIN depth := 0; i := from; gata := FALSE;
    WHILE ~gata & (i < to) DO
      c := Memorie.RCh(r, i);
      IF (c = "(") & (i + 1 < to) & (Memorie.RCh(r, i + 1) = "*") THEN
        e := IndexR(r, "*)", i, Memorie.recN[r]);
        IF e < 0 THEN gata := TRUE ELSE i := e + 2 END
      ELSE
        IF c = "(" THEN INC(depth) ELSIF c = ")" THEN DEC(depth) ELSIF (c = ";") & (depth = 0) THEN gata := TRUE END ;
        IF ~gata THEN INC(i) END
      END
    END ;
    e := i; WHILE (e < Memorie.recN[r]) & (Memorie.RCh(r, e) # 0AX) DO INC(e) END ;
    IF (e >= Memorie.recN[r]) OR (e > to) THEN e := i + 1; IF e > to THEN e := to END END ;
    TText(r, from, e)
  END AntetProc;

  (* comentariul lipit de antet (stilul lui Wirth), daca antetul n-a avut unul *)
  PROCEDURE ComentariuInterior(r, from, to: INTEGER; VAR d: ARRAY OF CHAR): BOOLEAN;
    VAR a, b, la, i, lim: INTEGER; ok, gol: BOOLEAN; c: ARRAY 4096 OF CHAR;
  BEGIN ok := FALSE; la := Iesire.tn;
    IF Litere.Pos("(*", Iesire.t, 0) < 0 THEN
      a := IndexR(r, "(*", from, Memorie.recN[r]);
      lim := from + la + 300; IF to < lim THEN lim := to END ;
      IF (a >= 0) & (a <= lim) THEN
        i := from + la; IF a < i THEN i := a END ;
        gol := TRUE; WHILE i < a DO IF Memorie.RCh(r, i) > " " THEN gol := FALSE END ; INC(i) END ;
        IF gol THEN
          b := IndexR(r, "*)", a, Memorie.recN[r]);
          IF (b >= a + 2) & (b <= to) THEN
            DeLaR(r, a + 2, b, c); Strange(c);
            IF Litere.Len(c) >= 3 THEN
              IF Litere.Len(c) > 300 THEN c[300] := 0X; Litere.Add(c, "…") END ;
              d := "Comentariul din cod: "; Litere.Add(d, c); ok := TRUE
            END
          END
        END
      END
    END ;
    RETURN ok
  END ComentariuInterior;

  PROCEDURE DespreDecl(k: INTEGER; n: ARRAY OF CHAR);
    VAR x, r, u, lin, i, nalte: INTEGER; mod, am, nm: Sir; com: ARRAY 4200 OF CHAR; b: BOOLEAN;
  BEGIN x := ld[0]; r := Memorie.dRec[x]; ultimRec := r; sigur := TRUE;
    ModIn(r, mod); Memorie.DNumeIn(x, nm);
    IF mod[0] # 0X THEN S(mod); S(".") END ;
    S(nm); S(" e "); S(felDecl[Memorie.dKind[x]]);
    IF Memorie.dLevel[x] > 0 THEN S(" locală (în interiorul altei proceduri)") ELSIF Memorie.dExp[x] THEN S(" exportată") ELSE S(" neexportată") END ;
    IF mod[0] # 0X THEN S(" din modulul "); S(mod) END ;
    S(" ("); Memorie.DialIn(r, am); S(am); S("):"); Ln;
    IF Memorie.dKind[x] = KProc THEN
      IF Memorie.dLevel[x] = 0 THEN u := Memorie.UnitDe(x) ELSE u := -1 END ;
      IF (u >= 0) & (Memorie.uKind[u] = KProc) THEN TText(r, Memorie.uFrom[u], Memorie.uHead[u])
      ELSE AntetProc(r, Memorie.dFrom[x], Memorie.dTo[x])
      END ;
      b := ComentariuInterior(r, Memorie.dFrom[x], Memorie.dTo[x], com);
      Iesire.CodT(14);
      IF b THEN Ln; S(com) END ;
      lin := Linii(r, Memorie.dFrom[x], Memorie.dTo[x]);
      Ln; S("("); Iesire.Cate(lin, "rând", "rânduri"); S("; scrie „arată ");
      IF mod[0] # 0X THEN S(mod); S(".") END ;
      S(nm); S("” pentru tot codul.)")
    ELSE
      TText(r, Memorie.dFrom[x], Memorie.dTo[x]); Iesire.CodT(14)
    END ;
    nsir := 0;
    FOR i := 1 TO k - 1 DO
      ModIn(Memorie.dRec[ld[i]], am);
      IF (am[0] # 0X) & (am # mod) THEN b := SirePune(am) END
    END ;
    nalte := nsir;
    IF nalte > 0 THEN
      Ln; S("Tot „"); S(n); S("” mai e declarat și în: "); SJoin(nalte, 10); IF nalte > 10 THEN S(" …") END ; S(".")
    END ;
    Nota("declarație · "); NotaSrc(r); NotaA(" · "); NotaNod(r)
  END DespreDecl;

  PROCEDURE Invatat(n: ARRAY OF CHAR): BOOLEAN;
    VAR u: INTEGER; s: ARRAY 600 OF CHAR; p: Sir; t: ARRAY 4096 OF CHAR; ok: BOOLEAN;
  BEGIN ok := FALSE; u := Memorie.nu - 1;
    Litere.Copy(n, p); Litere.MicS(p); Litere.AddCh(p, " ");
    WHILE ~ok & (u >= 0) DO
      IF Memorie.uKind[u] = KText THEN
        SrcIn(Memorie.uRec[u], s);
        IF Litere.Incepe(s, "învățat") THEN
          DeLaR(Memorie.uRec[u], Memorie.uFrom[u], Memorie.uTo[u], t); Litere.Trim(t);
          Litere.Copy(t, s); Litere.MicS(s);
          IF Litere.Incepe(s, p) THEN sigur := TRUE; Nota("m-ai învățat tu"); ultimRec := Memorie.uRec[u]; S(t); ok := TRUE END
        END
      END ;
      DEC(u)
    END ;
    RETURN ok
  END Invatat;

  PROCEDURE AreMici(s: ARRAY OF CHAR): BOOLEAN;
    VAR i: INTEGER; r: BOOLEAN;
  BEGIN r := FALSE; i := 0; WHILE s[i] # 0X DO IF Litere.Mica(s[i]) THEN r := TRUE END ; INC(i) END ;
    RETURN r
  END AreMici;

  PROCEDURE AreMari(s: ARRAY OF CHAR): BOOLEAN;
    VAR i: INTEGER; r: BOOLEAN;
  BEGIN r := FALSE; i := 0; WHILE s[i] # 0X DO IF Litere.Mare(s[i]) THEN r := TRUE END ; INC(i) END ;
    RETURN r
  END AreMari;

  (* FALSE daca nu stie nimic sigur despre nume (atunci cauta mai departe) *)
  PROCEDURE Defineste(nume, intrebare: ARRAY OF CHAR): BOOLEAN;
    VAR mod, n, nm: Sir; g: ARRAY 4096 OF CHAR; reg: ARRAY 400 OF CHAR; majuscule, mici, ok: BOOLEAN; km, kd: INTEGER;
  BEGIN Imparte(nume, mod, n); ok := TRUE;
    majuscule := ~AreMici(n) & (Litere.Len(n) > 1); mici := ~AreMari(n);
    IF (mod[0] = 0X) & Raport.Glosar(n, g) THEN
      sigur := TRUE; Nota("din glosarul meu");
      IF Raport.Regula(n, reg) & (Litere.Pos(reg, g, 0) < 0) & (majuscule OR mici) THEN
        FormatGlosar(g); Ln; S("Regula:"); Ln; Iesire.Cod(reg)
      ELSE FormatGlosar(g)
      END ;
      Memorie.Module(n, lm, km); Memorie.Declaratii(n, "", ld, kd);
      IF km > 0 THEN ModIn(lm[0], nm); Ln; S("(Am mâncat și modulul "); S(nm); S(": scrie „ce exportă "); S(nm); S("” sau „arată "); S(nm); S("”.)")
      ELSIF (kd > 0) & ~majuscule THEN
        Memorie.DNumeIn(ld[0], nm); Ln; S("(În cod mai e și „"); S(nm); S("” din modulul "); SModul(Memorie.dRec[ld[0]]);
        S(": scrie „unde e definit "); S(nm); S("”.)")
      END
    ELSIF (mod[0] = 0X) & Invatat(n) THEN
    ELSE
      km := 0; IF mod[0] = 0X THEN Memorie.Module(n, lm, km) END ;
      IF km > 0 THEN DespreModul(km)
      ELSE
        Memorie.Declaratii(n, mod, ld, kd);
        IF kd > 0 THEN DespreDecl(kd, n)
        ELSIF mod[0] # 0X THEN
          Memorie.Module(mod, lm, km);
          IF km = 0 THEN NecPune(mod); Nota("modul necunoscut"); S("N-am mâncat niciun modul „"); S(mod); S("”. Dacă îl ai, dă-mi-l cu Importă.")
          ELSE S("Modulul "); S(mod); S(" nu are nimic numit „"); S(n); S("”. Scrie „ce exportă "); S(mod); S("” ca să vezi ce are.")
          END
        ELSIF Memorie.Cauta(n) >= 0 THEN ok := FALSE                 (* apare in cod, dar nu e declarat: cautarea obisnuita *)
        ELSE NecPune(n); Nota("nume necunoscut"); Curios(nec[0], Litere.Seed(intrebare))
        END
      END
    END ;
    RETURN ok
  END Defineste;

  PROCEDURE Arata(nume: ARRAY OF CHAR);
    VAR mod, n, nm: Sir; k, km, x, r, from, to, u: INTEGER;
  BEGIN Imparte(nume, mod, n);
    Memorie.Declaratii(n, mod, ld, k); km := 0;
    IF (k = 0) & (mod[0] = 0X) THEN Memorie.Module(n, lm, km) END ;
    IF km > 0 THEN
      r := CelMaiCurat(km); ultimRec := r; sigur := TRUE;
      Nota("modul întreg · "); NotaSrc(r);
      S("Modulul "); SModul(r); S(" ("); SSrc(r); S("):"); Ln;
      TText(r, 0, Memorie.recN[r]); Iesire.CodT(120)
    ELSIF k = 0 THEN NecPune(nume); Nota("nume necunoscut"); S("N-am găsit „"); S(nume); S("” declarat nicăieri în ce am mâncat.")
    ELSE
      x := ld[0]; r := Memorie.dRec[x]; ultimRec := r; sigur := TRUE;
      from := Memorie.dFrom[x]; to := Memorie.dTo[x];
      IF (Memorie.dKind[x] # KProc) OR (Memorie.dLevel[x] = 0) THEN
        u := Memorie.UnitDe(x);
        IF (u >= 0) & (Memorie.uKind[u] = Memorie.dKind[x]) & (Memorie.dKind[x] # KConst) & (Memorie.dKind[x] # KVar) THEN
          IF Memorie.uFrom[u] < from THEN from := Memorie.uFrom[u] END ;
          IF Memorie.uTo[u] > to THEN to := Memorie.uTo[u] END
        END
      END ;
      Nota(felDecl[Memorie.dKind[x]]); NotaA(" · "); NotaSrc(r);
      ModIn(r, mod); IF mod[0] # 0X THEN S(mod); S(".") END ;
      Memorie.DNumeIn(x, nm); S(nm); S(":"); Ln;
      TText(r, from, to); Iesire.CodT(MAXRANDURI * 3)
    END
  END Arata;

  (* in randul de lucru: \bMod\s*.\s*Nume\b sau \bNume\b *)
  PROCEDURE InRand(mod, n: ARRAY OF CHAR): BOOLEAN;
    VAR i, j, lm2, ln, len: INTEGER; ok: BOOLEAN;

    PROCEDURE La(i: INTEGER; s: ARRAY OF CHAR): BOOLEAN;
      VAR k: INTEGER;
    BEGIN k := 0; WHILE (s[k] # 0X) & (linie[i+k] = s[k]) DO INC(k) END ;
      RETURN s[k] = 0X
    END La;

  BEGIN len := Litere.Len(linie); lm2 := Litere.Len(mod); ln := Litere.Len(n); ok := FALSE; i := 0;
    WHILE ~ok & (i < len) DO
      IF (i = 0) OR ~Litere.Cuvant(linie[i-1]) THEN
        IF lm2 > 0 THEN
          IF La(i, mod) THEN
            j := i + lm2; WHILE Spatiu(linie[j]) DO INC(j) END ;
            IF linie[j] = "." THEN INC(j); WHILE Spatiu(linie[j]) DO INC(j) END ;
              ok := La(j, n) & ~Litere.Cuvant(linie[j + ln])
            END
          END
        ELSE ok := La(i, n) & ~Litere.Cuvant(linie[i + ln])
        END
      END ;
      INC(i)
    END ;
    RETURN ok
  END InRand;

  PROCEDURE CuvantIntreg(s, w: ARRAY OF CHAR): BOOLEAN;   (* .*\bw\b.* *)
    VAR i, k, n, lw: INTEGER; ok: BOOLEAN;
  BEGIN n := Litere.Len(s); lw := Litere.Len(w); ok := FALSE; i := 0;
    WHILE ~ok & (i + lw <= n) DO
      IF ((i = 0) OR ~Litere.Cuvant(s[i-1])) THEN
        k := 0; WHILE (k < lw) & (s[i+k] = w[k]) DO INC(k) END ;
        ok := (k = lw) & ((i + lw = n) OR ~Litere.Cuvant(s[i+lw]))
      END ;
      INC(i)
    END ;
    RETURN ok
  END CuvantIntreg;

  PROCEDURE Exemple(nume: ARRAY OF CHAR);
    VAR mod, n, mm: Sir; k, nu, pas, i, a, b, r, j, nv, nmod, cut: INTEGER; gata, vazut, folosit: BOOLEAN;
      t: ARRAY 4096 OF CHAR; vaz: ARRAY 512 OF ARRAY 112 OF CHAR; mods: ARRAY 64 OF Sir;
  BEGIN Imparte(nume, mod, n);
    Memorie.Folosiri(n, mod, lu, nu);
    Iesire.TGol; k := 0; nv := 0; nmod := 0; pas := 0;
    WHILE (pas < 2) & (k < 6) DO
      i := 0;
      WHILE (i < nu) & (k < 6) DO
        r := Memorie.uRec[lu[i]]; ModIn(r, mm);
        folosit := FALSE; FOR j := 0 TO nmod - 1 DO IF mods[j] = mm THEN folosit := TRUE END END ;
        IF ~((pas = 0) & folosit) THEN
          a := Memorie.uFrom[lu[i]]; gata := FALSE;
          WHILE ~gata & (a < Memorie.uTo[lu[i]]) DO
            b := a; WHILE (b < Memorie.uTo[lu[i]]) & (Memorie.RCh(r, b) # 0AX) DO INC(b) END ;
            j := 0; cut := a;
            WHILE (cut < b) & (j < LEN(linie) - 1) DO IF Memorie.RCh(r, cut) # 0DX THEN linie[j] := Memorie.RCh(r, cut); INC(j) END ; INC(cut) END ;
            linie[j] := 0X;
            Litere.Copy(linie, t); Litere.Trim(t);
            j := 0; WHILE Spatiu(linie[j]) DO INC(j) END ;
            IF InRand(mod, n)
              & ~(Litere.Incepe(t, "PROCEDURE") & ((t[9] = 0X) OR ~Litere.Cuvant(t[9])))
              & ~Litere.Incepe(t, "(*") & (Litere.Len(t) <= 110) THEN
              vazut := FALSE; FOR j := 0 TO nv - 1 DO IF vaz[j] = t THEN vazut := TRUE END END ;
              IF ~vazut THEN
                IF nv < LEN(vaz) THEN Litere.Copy(t, vaz[nv]); INC(nv) END ;
                IF ~CuvantIntreg(t, "PROCEDURE") & ~Litere.Incepe(t, "IMPORT") THEN
                  Iesire.TS(mm); Iesire.TS(": "); Iesire.TS(t); Iesire.TC(0AX);
                  IF nmod < LEN(mods) THEN mods[nmod] := mm; INC(nmod) END ;
                  INC(k); gata := TRUE
                END
              END
            END ;
            a := b + 1
          END
        END ;
        INC(i)
      END ;
      INC(pas)
    END ;
    IF k = 0 THEN
      cut := Iesire.n;
      S("N-am găsit locuri unde e folosit. ");
      IF ~Defineste(nume, nume) THEN Iesire.Inapoi(cut); S("N-am găsit „"); S(nume); S("” folosit nicăieri.") END
    ELSE
      sigur := TRUE; nota := ""; Iesire.CateIn(nota, nu, "unitate îl folosește", "unități îl folosesc");
      S("Cum e folosit "); S(nume); S(" în codul pe care l-am mâncat:"); Ln; Iesire.CodT(1000000)
    END
  END Exemple;

  PROCEDURE Folosiri(nume: ARRAY OF CHAR);
    VAR mod, n, mm, un, e: Sir; nu, i, u: INTEGER; b: BOOLEAN;
  BEGIN Imparte(nume, mod, n);
    Memorie.Folosiri(n, mod, lu, nu);
    IF nu = 0 THEN S("N-am găsit „"); S(nume); S("” folosit nicăieri.")
    ELSE nsir := 0;
      FOR i := 0 TO nu - 1 DO
        u := lu[i]; ModIn(Memorie.uRec[u], mm); Memorie.UNumeIn(u, un);
        IF ~((Memorie.uKind[u] = KProc) & (un = n) & ((mod[0] = 0X) OR (mm = mod))) THEN
          e := mm;
          IF Memorie.uKind[u] = KProc THEN Litere.Add(e, "."); Litere.Add(e, un) ELSIF Memorie.uKind[u] = KCorp THEN Litere.Add(e, " (corpul)") END ;
          b := SirePune(e)
        END
      END ;
      sigur := TRUE; Nota("căutat în toate unitățile");
      S(nume); S(" apare în "); Iesire.Cate(nsir, "loc", "locuri"); S(": "); SJoin(nsir, 20); IF nsir > 20 THEN S(" …") END ; S(".")
    END
  END Folosiri;

  PROCEDURE CeImporta(mod: ARRAY OF CHAR);
    VAR km, r, i: INTEGER; m: Sir;
  BEGIN Memorie.Module(mod, lm, km);
    IF km = 0 THEN NecPune(mod); S("N-am mâncat niciun modul „"); S(mod); S("”.")
    ELSE r := lm[0]; ultimRec := r; sigur := TRUE;
      SModul(r);
      IF Memorie.recImpN[r] = 0 THEN S(" nu importă nimic.")
      ELSE S(" importă: ");
        FOR i := 0 TO Memorie.recImpN[r] - 1 DO IF i > 0 THEN S(", ") END ; Memorie.ImpIn(Memorie.recImpA[r] + i, m); S(m) END ;
        S(".")
      END
    END
  END CeImporta;

  (* lista de nume, sortata fara sa conteze literele mari, fara dubluri (ca TreeSet cu CASE_INSENSITIVE_ORDER) *)
  PROCEDURE PuneSortat(s: ARRAY OF CHAR);
    VAR i, j: INTEGER; exista: BOOLEAN;
  BEGIN exista := FALSE; i := 0;
    WHILE ~exista & (i < nsir) DO exista := MicEq(siruri[i], s); INC(i) END ;
    IF ~exista & (nsir < LEN(siruri)) THEN
      i := nsir; WHILE (i > 0) & MicLess(s, siruri[i-1]) DO siruri[i] := siruri[i-1]; DEC(i) END ;
      Litere.Copy(s, siruri[i]); INC(nsir); j := 0
    END
  END PuneSortat;

  PROCEDURE CineImporta(mod: ARRAY OF CHAR);
    VAR r, i: INTEGER; m, mm: Sir;
  BEGIN nsir := 0;
    FOR r := 0 TO Memorie.nrec - 1 DO
      IF Memorie.recModN[r] > 0 THEN
        FOR i := 0 TO Memorie.recImpN[r] - 1 DO
          Memorie.ImpIn(Memorie.recImpA[r] + i, m);
          IF MicEq(m, mod) THEN ModIn(r, mm); PuneSortat(mm) END
        END
      END
    END ;
    IF nsir = 0 THEN S("Niciun modul din ce am mâncat nu importă „"); S(mod); S("”.")
    ELSE sigur := TRUE; Iesire.Cate(nsir, "modul", "module"); S(" importă "); S(mod); S(": "); SJoin(nsir, 40); IF nsir > 40 THEN S(" …") END ; S(".")
    END
  END CineImporta;

  PROCEDURE CeExporta(mod: ARRAY OF CHAR);
    VAR km, r, k, x: INTEGER; nm: Sir; b: BOOLEAN; felN: ARRAY 5 OF ARRAY 16 OF CHAR;
  BEGIN Memorie.Module(mod, lm, km);
    IF km = 0 THEN NecPune(mod); S("N-am mâncat niciun modul „"); S(mod); S("”.")
    ELSE r := CelMaiCurat(km); ultimRec := r; sigur := TRUE;
      felN[1] := "Constante"; felN[2] := "Tipuri"; felN[3] := "Variabile"; felN[4] := "Proceduri";
      SModul(r); S(" exportă:");
      FOR k := 1 TO 4 DO
        nsir := 0;
        FOR x := 0 TO Memorie.nd - 1 DO
          IF (Memorie.dRec[x] = r) & Memorie.dExp[x] & (Memorie.dLevel[x] = 0) & (Memorie.dKind[x] = k) THEN Memorie.DNumeIn(x, nm); b := SirePune(nm) END
        END ;
        IF nsir > 0 THEN Ln; S(felN[k]); S(" ("); Iesire.Int(nsir); S("): "); SJoin(nsir, 40); IF nsir > 40 THEN S(" …") END END
      END ;
      nota := ""; NotaSrc(r)
    END
  END CeExporta;

  PROCEDURE Module;
    VAR r, po, voc, alt: INTEGER; m: Sir; s: ARRAY 600 OF CHAR;
  BEGIN nsir := 0; po := 0; voc := 0; alt := 0;
    FOR r := 0 TO Memorie.nrec - 1 DO
      IF Memorie.recModN[r] > 0 THEN
        ModIn(r, m); PuneSortat(m);
        SrcIn(r, s); Litere.MicS(s);
        IF Litere.Incepe(s, "project oberon") THEN INC(po) ELSIF Litere.Pos("/voc/", s, 0) >= 0 THEN INC(voc) ELSE INC(alt) END
      END
    END ;
    sigur := TRUE;
    S("Am mâncat "); Iesire.Cate(po + voc + alt, "fișier", "fișiere"); S(" cu module ("); Iesire.Int(po); S(" din Project Oberon 2013, ");
    Iesire.Int(voc); S(" din voc, "); Iesire.Int(alt); S(" de pe telefonul tău sau importate), "); Iesire.Cate(nsir, "nume", "nume");
    S(" diferite: "); SJoin(nsir, 80); IF nsir > 80 THEN S(" …") END ; S(".")
  END Module;

  PROCEDURE Unde(nume: ARRAY OF CHAR);
    VAR mod, n, m: Sir; k, km, i, j, x, nd2: INTEGER; dub: BOOLEAN;
  BEGIN Imparte(nume, mod, n);
    Memorie.Declaratii(n, mod, ld, k);
    IF k = 0 THEN
      Memorie.Module(n, lm, km);
      IF km > 0 THEN sigur := TRUE; S("Modulul "); S(n); S(" e în: "); FOR i := 0 TO km - 1 DO Ln; S("· "); SSrc(lm[i]) END
      ELSE NecPune(nume); S("N-am găsit „"); S(nume); S("” declarat nicăieri.")
      END
    ELSE sigur := TRUE; nd2 := 0;
      FOR i := 0 TO k - 1 DO                                 (* fara dubluri: acelasi fisier, fel si nivel *)
        x := ld[i]; dub := FALSE;
        FOR j := 0 TO nd2 - 1 DO
          IF (Memorie.dRec[lx[j]] = Memorie.dRec[x]) & (Memorie.dKind[lx[j]] = Memorie.dKind[x]) & (Memorie.dLevel[lx[j]] = Memorie.dLevel[x]) THEN dub := TRUE END
        END ;
        IF ~dub THEN lx[nd2] := x; INC(nd2) END
      END ;
      S(n); S(" e declarat în "); Iesire.Cate(nd2, "loc", "locuri"); S(":");
      FOR i := 0 TO nd2 - 1 DO
        IF i < 12 THEN
          x := lx[i]; Ln; S("· "); ModIn(Memorie.dRec[x], m); IF m[0] # 0X THEN S(m) ELSE S("?") END ;
          S(" — "); S(felDecl[Memorie.dKind[x]]);
          IF Memorie.dExp[x] THEN S(", exportat") END ; IF Memorie.dLevel[x] > 0 THEN S(", local") END ;
          S(" ("); SSrc(Memorie.dRec[x]); S(")")
        END
      END ;
      IF nd2 > 12 THEN Ln; S("…") END
    END
  END Unde;

  (* ---------- verificarea ---------- *)

  PROCEDURE Verifica*(VAR text: ARRAY OF CHAR; len: INTEGER);
    VAR i, proc, km, nl: INTEGER; m: Sir; o: ARRAY 80 OF CHAR; lipsa: BOOLEAN;
  BEGIN Iesire.Gol; nota := ""; sigur := FALSE; nnec := 0;
    Gramatica.Analizeaza(text, len);
    sigur := Gramatica.ok;
    IF Gramatica.ok THEN
      S("✓ Corect ");
      IF Gramatica.fel = 0 THEN S("— modulul "); Gramatica.Nume(Gramatica.modA, Gramatica.modN, m); IF Gramatica.modN > 0 THEN S(m) ELSE S("null") END
      ELSIF Gramatica.fel = 1 THEN S("— sunt declarații")
      ELSE S("— sunt instrucțiuni")
      END ;
      IF Gramatica.no2 = 0 THEN S(", după gramatica Oberon-07.")
      ELSE S(", dar e Oberon-2 (nu Oberon-07): ");
        FOR i := 0 TO Gramatica.no2 - 1 DO
          IF i > 0 THEN S("; ") END ; Gramatica.O2Text(Gramatica.o2fel[i], o); S(o); S(" la linia "); Iesire.Int(Gramatica.o2lin[i])
        END ;
        S(".")
      END ;
      S(" "); Iesire.Cate(Gramatica.simboluri, "simbol", "simboluri");
      proc := 0; FOR i := 0 TO Gramatica.nd - 1 DO IF Gramatica.dKind[i] = KProc THEN INC(proc) END END ;
      IF proc > 0 THEN S(", "); Iesire.Int(proc); IF proc = 1 THEN S(" procedură") ELSE S(" proceduri") END END ;
      IF Gramatica.nimp > 0 THEN
        S("; importă ");
        FOR i := 0 TO Gramatica.nimp - 1 DO IF i > 0 THEN S(", ") END ; Gramatica.Nume(Gramatica.impA[i], Gramatica.impN[i], m); S(m) END ;
        lipsa := FALSE; nl := 0;
        FOR i := 0 TO Gramatica.nimp - 1 DO
          Gramatica.Nume(Gramatica.impA[i], Gramatica.impN[i], m);
          IF m # "SYSTEM" THEN
            Memorie.Module(m, lm, km);
            IF km = 0 THEN IF ~lipsa THEN S(" (pe ") ELSE S(", ") END ; lipsa := TRUE; S(m); INC(nl) END
          END
        END ;
        IF lipsa THEN S(" nu-l am în memorie)") END
      END ;
      S(".");
      Nota("verificat cu regulile din raport (doar sintaxa: tipurile și numele nu le verific încă)")
    ELSE
      S("✗ Linia "); Iesire.Int(Gramatica.linie); S(", coloana "); Iesire.Int(Gramatica.coloana); S(": "); S(Gramatica.eroare); S("."); Ln;
      Iesire.TGol; Iesire.TS(Gramatica.randul); Iesire.TC(0AX);
      FOR i := 1 TO Gramatica.coloana - 1 DO Iesire.TC(" ") END ;
      Iesire.TC("^"); Iesire.CodT(1000000);
      Nota("verificat cu regulile din raport")
    END
  END Verifica;

  (* ---------- cautarea prin sorobanul 7D si Opal ---------- *)

  PROCEDURE Contine(q, p: ARRAY OF CHAR): BOOLEAN;   (* .*\bp\b.* *)
  BEGIN RETURN CuvantIntreg(q, p)
  END Contine;

  PROCEDURE ContineUna(q, lista: ARRAY OF CHAR): BOOLEAN;
    VAR i, j: INTEGER; w: Sir; r: BOOLEAN;
  BEGIN r := FALSE; i := 0;
    WHILE ~r & (lista[i] # 0X) DO
      j := 0; WHILE (lista[i] # 0X) & (lista[i] # "|") DO w[j] := lista[i]; INC(i); INC(j) END ;
      w[j] := 0X; IF lista[i] = "|" THEN INC(i) END ;
      r := Contine(q, w)
    END ;
    RETURN r
  END ContineUna;

  PROCEDURE Rol(q: ARRAY OF CHAR): INTEGER;
    VAR r: INTEGER;
  BEGIN
    IF ContineUna(q, "ce procedura|ce functie|cum pot|cum fac|cum se|cum sa|cum scriu|cum citesc|cum deschid|ce comanda|cu ce procedura|ce apelez") THEN r := PROC
    ELSIF ContineUna(q, "ce tip|ce structura|ce record|ce inregistrare") THEN r := TIP
    ELSIF ContineUna(q, "ce constant|ce valoare|cat e|cat este|cat valoreaza") THEN r := CONSTANTA
    ELSIF ContineUna(q, "ce variabil") THEN r := VARIABILA
    ELSIF ContineUna(q, "ce modul|in ce modul|care modul|din ce modul") THEN r := MODUL
    ELSIF ContineUna(q, "raport|raportul|wirth spune|ce spune limbajul") THEN r := TEXT
    ELSE r := ORICE
    END ;
    RETURN r
  END Rol;

  PROCEDURE Potrivit(r, u: INTEGER): BOOLEAN;
    VAR k: INTEGER; ok: BOOLEAN;
  BEGIN k := Memorie.uKind[u];
    IF r = PROC THEN ok := k = KProc ELSIF r = TIP THEN ok := k = KType ELSIF r = CONSTANTA THEN ok := k = KConst
    ELSIF r = VARIABILA THEN ok := k = KVar ELSIF r = MODUL THEN ok := k = KModul ELSIF r = TEXT THEN ok := k = KText
    ELSE ok := TRUE
    END ;
    RETURN ok
  END Potrivit;

  PROCEDURE GrupAre(g, id: INTEGER): BOOLEAN;
    VAR i: INTEGER; r: BOOLEAN;
  BEGIN r := FALSE; FOR i := gA[g] TO gA[g] + gN[g] - 1 DO IF gIds[i] = id THEN r := TRUE END END ;
    RETURN r
  END GrupAre;

  PROCEDURE GrupPune(id: INTEGER);   (* in grupul care se face acum (ngr) *)
  BEGIN IF ~GrupAre(ngr, id) & (ngi < MaxGi) THEN gIds[ngi] := id; INC(ngi); INC(gN[ngr]) END
  END GrupPune;

  PROCEDURE NumePotrivit(u: INTEGER): INTEGER;
    VAR k, g, i: INTEGER; nm: Sir; l: ARRAY 64 OF CHAR; gasit: BOOLEAN;
  BEGIN k := 0;
    IF Memorie.uKind[u] # KText THEN
      Memorie.UNumeIn(u, nm);
      Memorie.Cuvinte(nm, 0, Litere.Len(nm));
      FOR g := 0 TO ngr - 1 DO
        gasit := FALSE; i := gA[g];
        WHILE ~gasit & (i < gA[g] + gN[g]) DO Memorie.LemaIn(gIds[i], l); gasit := Memorie.CwContine(l); INC(i) END ;
        IF gasit THEN INC(k) END
      END
    END ;
    RETURN k
  END NumePotrivit;

  (* cele 5 verificari ale lui Opal: {cuvintele, unda, rolul, gramatica, vecinii} *)
  PROCEDURE Opal(u, lit, sc, r: INTEGER; VAR v: ARRAY OF INTEGER);
    VAR comune, g, i, d, x: INTEGER; gasit, ctx: BOOLEAN;
  BEGIN comune := 0;
    FOR g := 0 TO ngr - 1 DO
      gasit := FALSE; i := gA[g];
      WHILE ~gasit & (i < gA[g] + gN[g]) DO gasit := Memorie.Are(u, gIds[i]); INC(i) END ;
      IF gasit THEN INC(comune) END
    END ;
    d := (ngr + 1) DIV 2; IF d < 1 THEN d := 1 END ;
    IF comune >= d THEN v[0] := 1 ELSE v[0] := 0 END ;
    IF (lit > 0) & (sc >= lit) THEN v[1] := 1 ELSE v[1] := 0 END ;
    IF Potrivit(r, u) THEN v[2] := 1 ELSE v[2] := 0 END ;
    IF Memorie.uCurat[u] THEN v[3] := 1 ELSE v[3] := 0 END ;
    ctx := FALSE; d := -1;
    WHILE ~ctx & (d <= 1) DO
      x := u + d;
      IF (x >= 0) & (x < Memorie.nu) & (Memorie.uRec[x] = Memorie.uRec[u]) THEN
        g := 0;
        WHILE ~ctx & (g < ngr) DO
          i := gA[g]; WHILE ~ctx & (i < gA[g] + gN[g]) DO ctx := Memorie.Are(x, gIds[i]); INC(i) END ;
          INC(g)
        END
      END ;
      d := d + 2
    END ;
    IF ctx THEN v[4] := 1 ELSE v[4] := 0 END
  END Opal;

  PROCEDURE Semne(VAR v: ARRAY OF INTEGER; VAR d: ARRAY OF CHAR);
    VAR i: INTEGER; nume: ARRAY 5 OF ARRAY 4 OF CHAR;
  BEGIN nume[0] := "1"; nume[1] := "3"; nume[2] := "5"; nume[3] := "7"; nume[4] := "11"; d[0] := 0X;
    FOR i := 0 TO 4 DO IF v[i] = 1 THEN IF d[0] # 0X THEN Litere.Add(d, "·") END ; Litere.Add(d, nume[i]) END END
  END Semne;

  (* cum arata o unitate in raspuns *)
  PROCEDURE Prezinta(u: INTEGER);
    VAR k, r: INTEGER; mod, nm: Sir;
  BEGIN k := Memorie.uKind[u]; r := Memorie.uRec[u]; ModIn(r, mod);
    IF k = KText THEN
      IF mod[0] # 0X THEN S(mod); S(" — ") END ;
      TText(r, Memorie.uFrom[u], Memorie.uTo[u]); Iesire.TTrim; Iesire.TaieT(12);
      S("  ("); SSrc(r); S(")")
    ELSE
      IF k = KModul THEN S("Modulul "); S(mod)
      ELSE Memorie.UNumeIn(u, nm); S(mod); S("."); S(nm); S(" — "); S(fel[k]); IF Memorie.uExp[u] THEN S(", exportat") END
      END ;
      S(":"); Ln;
      IF k = KProc THEN TText(r, Memorie.uFrom[u], Memorie.uHead[u]) ELSE TText(r, Memorie.uFrom[u], Memorie.uTo[u]) END ;
      k := 0; WHILE (k < Iesire.tn) & (Iesire.t[k] <= " ") DO INC(k) END ;
      IF k = Iesire.tn THEN TText(r, Memorie.uFrom[u], Memorie.uTo[u]) END ;
      Iesire.CodT(12)
    END
  END Prezinta;

  (* sortare stabila (prin interclasare) a lui cand[0..n) dupa cheie descrescator, apoi index crescator *)
  PROCEDURE Sorteaza(n: INTEGER; VAR cheie: ARRAY OF REAL);
    VAR w, i, a, b, ea, eb, k: INTEGER; ka, kb: REAL; iaA: BOOLEAN;
  BEGIN w := 1;
    WHILE w < n DO
      i := 0;
      WHILE i < n DO
        a := i; ea := i + w; IF ea > n THEN ea := n END ;
        b := ea; eb := ea + w; IF eb > n THEN eb := n END ;
        k := i;
        WHILE (a < ea) OR (b < eb) DO
          IF a >= ea THEN iaA := FALSE ELSIF b >= eb THEN iaA := TRUE
          ELSE ka := cheie[cand[a]]; kb := cheie[cand[b]];
            iaA := (ka > kb) OR (ka = kb) & (cand[a] < cand[b])
          END ;
          IF iaA THEN tmpI[k] := cand[a]; INC(a) ELSE tmpI[k] := cand[b]; INC(b) END ;
          INC(k)
        END ;
        i := i + 2 * w
      END ;
      FOR i := 0 TO n - 1 DO cand[i] := tmpI[i] END ;
      w := 2 * w
    END
  END Sorteaza;

  PROCEDURE Cauta(intrebare: ARRAY OF CHAR);
    VAR i, n, a, id, g, p, u, L, k, lit, r, nt, x, cnt, j: INTEGER; f, b: REAL; w, l: ARRAY 64 OF CHAR; lem: ARRAY 64 OF CHAR;
      trec: ARRAY 2 OF INTEGER; v: ARRAY 5 OF INTEGER; jurnal: ARRAY 32 OF CHAR; q: ARRAY 4096 OF CHAR; dub: BOOLEAN;
  BEGIN ngr := 0; ngi := 0; ntoate := 0; n := Litere.Len(intrebare); i := 0;
    (* grupurile: fiecare cuvant al intrebarii, cu traducerile si bucatile lui *)
    WHILE i < n DO
      IF Litere.Litera(intrebare[i]) OR (intrebare[i] = "_") THEN
        a := i;
        WHILE (i < n) & (Litere.Litera(intrebare[i]) OR Litere.Cifra(intrebare[i]) OR (intrebare[i] = "_")) DO INC(i) END ;
        Litere.Sub(intrebare, a, i, w);
        Litere.Copy(w, l); Litere.MicFold(l);
        IF (Litere.Continut(l) OR (Litere.Len(w) >= 2) & AreMari(w)) & (ngr < MaxGr) THEN
          gA[ngr] := ngi; gN[ngr] := 0;
          id := Memorie.Cauta(w); IF id >= 0 THEN GrupPune(id) END ;
          Raport.Engleza(w);
          FOR k := 0 TO Raport.nen - 1 DO id := Memorie.Cauta(Raport.en[k]); IF id >= 0 THEN GrupPune(id) END END ;
          IF gN[ngr] = 0 THEN
            Memorie.Cuvinte(w, 0, Litere.Len(w));
            FOR k := 0 TO Memorie.ncw - 1 DO Memorie.CwIn(k, lem); id := Memorie.Cauta(lem); IF id >= 0 THEN GrupPune(id) END END
          END ;
          IF gN[ngr] = 0 THEN
            IF Litere.Litera(w[0]) & ~NecAre(w) & Litere.Continut(l) THEN NecPune(w) END
          ELSE
            FOR k := gA[ngr] TO gA[ngr] + gN[ngr] - 1 DO
              dub := FALSE; FOR j := 0 TO ntoate - 1 DO IF toate[j] = gIds[k] THEN dub := TRUE END END ;
              IF ~dub & (ntoate < MaxGi) THEN toate[ntoate] := gIds[k]; INC(ntoate) END
            END ;
            INC(ngr)
          END
        END
      ELSE INC(i)
      END
    END ;
    IF ngr = 0 THEN
      IF nnec > 0 THEN Nota("cuvinte necunoscute"); Curios(nec[0], Litere.Seed(intrebare))
      ELSE S("Nu știu încă nimic despre asta. Eu știu doar Oberon: întreabă-mă de un modul, o procedură sau un cuvânt al limbii.")
      END
    ELSE
      (* 1. candidatele, dupa suma idf (un grup conteaza o data) *)
      INC(stampQ); ncand := 0;
      FOR g := 0 TO ngr - 1 DO
        INC(stampG); nglist := 0;
        FOR k := gA[g] TO gA[g] + gN[g] - 1 DO
          id := gIds[k]; cnt := Memorie.lemCnt[id]; IF cnt < 1 THEN cnt := 1 END ;
          f := Math.ln(1.0 + FLT(Memorie.nu) / FLT(cnt));
          p := Memorie.Prima(id);
          WHILE p >= 0 DO
            u := Memorie.UnitP(p);
            IF bStamp[u] # stampG THEN bStamp[u] := stampG; best[u] := f; glist[nglist] := u; INC(nglist)
            ELSIF best[u] < f THEN best[u] := f
            END ;
            p := Memorie.Urmatoarea(p)
          END
        END ;
        FOR k := 0 TO nglist - 1 DO
          u := glist[k];
          IF scStamp[u] # stampQ THEN scStamp[u] := stampQ; scor[u] := 0.0; tmpI[ncand] := u; INC(ncand) END ;
          scor[u] := scor[u] + best[u]
        END
      END ;
      nt := 0;
      FOR k := 0 TO ncand - 1 DO
        u := tmpI[k]; L := Memorie.Lungime(u);
        IF (L >= 20) & (L <= 60000) & (Memorie.uKind[u] # KCorp) THEN
          b := scor[u] + 2.0 * FLT(NumePotrivit(u)) + 0.3 * FLT(3 - Memorie.recRang[Memorie.uRec[u]]);
          IF Memorie.uExp[u] THEN b := b + 0.5 END ;
          scor[u] := b; glist[nt] := u; INC(nt)
        END
      END ;
      IF nt = 0 THEN S("N-am citit încă nimic despre asta.")
      ELSE
        FOR k := 0 TO nt - 1 DO cand[k] := glist[k] END ;
        Sorteaza(nt, scor);
        IF nt > POOL THEN nt := POOL END ;
        (* 2. sorobanul 7D: intrebarea si fiecare unitate lasa o urma; cea mai apropiata urca *)
        Soroban7.Goleste(Soroban7.sq);
        FOR k := 0 TO ntoate - 1 DO Memorie.LemaIn(toate[k], lem); Soroban7.Cuvant(Soroban7.sq, lem) END ;
        lit := Soroban7.Aprinse(Soroban7.sq);
        FOR k := 0 TO nt - 1 DO
          u := cand[k]; Soroban7.Goleste(Soroban7.sf);
          j := 0;
          WHILE (j < Memorie.uLemN[u]) & (j < 20) DO Memorie.LemaIn(Memorie.ulem[Memorie.uLemA[u] + j], lem); Soroban7.Cuvant(Soroban7.sf, lem); INC(j) END ;
          sorSc[u] := Soroban7.Scor(Soroban7.sq, Soroban7.sf);
          tmpR[u] := scor[u] * 1000.0 + FLT(sorSc[u])
        END ;
        Sorteaza(nt, tmpR);
        (* 3. Opal *)
        Litere.Copy(intrebare, q); Litere.MicFold(q); r := Rol(q);
        x := 0; jurnal := ""; k := 0;
        WHILE (k < OPALN * 3) & (k < nt) & (x < 2) DO
          u := cand[k];
          Opal(u, lit, sorSc[u], r, v);
          a := v[0] + v[1] + v[2] + v[3] + v[4];
          IF ~((a < OPALPRAG) OR (k >= OPALN) & (x = 0) & (v[0] = 0)) THEN
            dub := FALSE;
            FOR j := 0 TO x - 1 DO
              IF Memorie.AcelasiText(trec[j], u) THEN dub := TRUE END ;
              IF (Memorie.uKind[trec[j]] = Memorie.uKind[u]) THEN
                Memorie.UNumeIn(trec[j], w); Memorie.UNumeIn(u, l);
                IF w = l THEN dub := TRUE END
              END
            END ;
            IF ~dub THEN trec[x] := u; INC(x); IF jurnal[0] = 0X THEN Semne(v, jurnal) END END
          END ;
          INC(k)
        END ;
        IF x = 0 THEN
          u := cand[0]; ultimRec := Memorie.uRec[u];
          Nota("Opal: nicio unitate n-a trecut 3 din 5 · "); NotaSrc(ultimRec); NotaA(" · "); NotaNod(ultimRec);
          NuStiu(Litere.Seed(intrebare)); S(" Cel mai aproape am găsit:"); Ln; Prezinta(u)
        ELSE
          sigur := TRUE; ultimRec := Memorie.uRec[trec[0]];
          Nota("Opal "); NotaA(jurnal); IF r # ORICE THEN NotaA(" · rol: "); NotaA(rolNume[r]) END ;
          NotaA(" · "); NotaSrc(ultimRec); NotaA(" · "); NotaNod(ultimRec);
          FOR j := 0 TO x - 1 DO IF j > 0 THEN Ln END ; Prezinta(trec[j]) END
        END
      END
    END
  END Cauta;

  PROCEDURE GolNota*;
  BEGIN nota := ""
  END GolNota;

  (* ---------- intrarea ---------- *)

  PROCEDURE Raspunde*(raw: ARRAY OF CHAR);
    VAR f, rest, nume, g: ARRAY 4096 OF CHAR; ok: BOOLEAN; i, n, k, pas: INTEGER; w: Sir;
  BEGIN nota := ""; sigur := FALSE; nnec := 0;
    Norm(raw, f);
    IF f[0] = 0X THEN S("Scrie-mi ceva despre Oberon.")
    ELSIF Litere.Incepe(f, "regula") OR Litere.Incepe(f, "sintaxa") OR Litere.Incepe(f, "ebnf") OR Litere.Incepe(f, "gramatica") OR Litere.Incepe(f, "scrie regula") THEN
      IF Litere.Incepe(f, "regula") THEN k := 6 ELSIF Litere.Incepe(f, "sintaxa") THEN k := 7 ELSIF Litere.Incepe(f, "ebnf") THEN k := 4
      ELSIF Litere.Incepe(f, "gramatica") THEN k := 9 ELSE k := 12 END ;
      Litere.Sub(f, k, Litere.Len(f), rest);
      IF Litere.Incepe(rest, " lui") THEN Litere.Sub(rest, 4, Litere.Len(rest), rest)
      ELSIF Litere.Incepe(rest, " pentru") THEN Litere.Sub(rest, 7, Litere.Len(rest), rest)
      ELSIF Litere.Incepe(rest, " de la") THEN Litere.Sub(rest, 6, Litere.Len(rest), rest)
      ELSIF Litere.Incepe(rest, " la") THEN Litere.Sub(rest, 3, Litere.Len(rest), rest)
      END ;
      Litere.Trim(rest); Regula(rest)
    ELSIF Unul(f, "ce module stii|ce module ai|ce module cunosti|ce module ai mancat|lista modulelor|modulele|toate modulele|module|ce module") THEN Module
    ELSIF Forma(f, "arata|arata-mi|arata mi|da-mi codul|da mi codul|codul|show|listeaza|vreau sa vad", "mi|tot", TRUE, TRUE, rest) THEN
      Orig(raw, rest, nume); Arata(nume)
    ELSIF Forma(f, "cum folosesc|cum se foloseste|cum folosim|cum chem|cum apelez|cum se cheama|cum se apeleaza|exemplu|exemple|un exemplu|exemplul|da-mi un exemplu|da mi un exemplu", "de|cu|pentru|la", TRUE, TRUE, rest) THEN
      Orig(raw, rest, nume); Exemple(nume)
    ELSIF Forma(f, "cine foloseste|cine apeleaza|cine cheama|unde e folosit|unde e folosita|unde e foloseste|unde e apelat|unde e apelata", "", TRUE, TRUE, rest)
      OR Forma(f, "unde este folosit|unde este folosita|unde este foloseste|unde este apelat|unde este apelata|unde se folosit|unde se folosita", "", TRUE, TRUE, rest)
      OR Forma(f, "unde se foloseste|unde se apelat|unde se apelata|unde apare|in ce module e folosit|in ce module este folosit", "", TRUE, TRUE, rest) THEN
      Orig(raw, rest, nume); Folosiri(nume)
    ELSIF Forma(f, "ce importa|ce foloseste", "modulul", FALSE, TRUE, rest) THEN Orig(raw, rest, nume); CeImporta(nume)
    ELSIF Forma(f, "cine importa|ce module importa|cine foloseste modulul", "pe", FALSE, TRUE, rest) THEN Orig(raw, rest, nume); CineImporta(nume)
    ELSIF Forma(f, "ce exporta|ce are modulul|ce contine modulul|ce ofera modulul|ce proceduri are|ce e in|ce este in", "modulul", FALSE, TRUE, rest) THEN
      Orig(raw, rest, nume); CeExporta(nume)
    ELSIF Forma(f, "unde e definit|unde e definita|unde e declarat|unde e declarata|unde este definit|unde este definita|unde este declarat|unde este declarata|unde e|unde este|in ce modul e|in ce modul este|din ce modul e|din ce modul este", "", TRUE, TRUE, rest) THEN
      Orig(raw, rest, nume); Unde(nume)
    ELSE
      ok := FALSE;
      IF Forma(f, "ce este|ce e|ce face|ce inseamna|ce reprezinta|ce sunt|ce returneaza|ce intoarce|cine e|cine este|cine a fost|defineste|explica-mi|explica mi|explica|spune-mi despre|spune mi despre|ce stii despre|despre", "", TRUE, FALSE, rest) THEN
        Litere.Trim(rest);
        IF EsteNume(rest) THEN Orig(raw, rest, nume); ok := Defineste(nume, raw)
        ELSE
          n := 1; i := 0; WHILE rest[i] # 0X DO IF rest[i] = " " THEN INC(n) END ; INC(i) END ;
          IF n <= 6 THEN                                     (* „ce este o procedura legata de tip” *)
            ok := Raport.Glosar(rest, g); pas := 0;
            WHILE ~ok & (pas < 2) DO
              i := 0; n := Litere.Len(rest);
              WHILE ~ok & (i < n) DO
                k := i; WHILE (k < n) & (rest[k] # " ") DO INC(k) END ;
                Litere.Sub(rest, i, k, w);
                IF ((pas = 1) OR ~Unul(w, "procedura|procedure|tip|type|modul|module|variabila|constanta")) & Litere.Continut(w) THEN ok := Raport.Glosar(w, g) END ;
                i := k + 1
              END ;
              INC(pas)
            END ;
            IF ok THEN sigur := TRUE; Nota("din glosarul meu"); FormatGlosar(g) END
          END
        END
      END ;
      IF ~ok & EsteNume(f) THEN Orig(raw, f, nume); ok := Defineste(nume, raw) END ;
      IF ~ok THEN Cauta(raw) END
    END
  END Raspunde;

  PROCEDURE U(s: ARRAY OF CHAR); BEGIN Litere.Copy(s, umplutura[numpl]); INC(numpl) END U;

BEGIN ultimRec := -1; sigur := FALSE; nnec := 0; stampQ := 0; stampG := 0; numpl := 0;
  felDecl[0] := "modul"; felDecl[1] := "constantă"; felDecl[2] := "tip"; felDecl[3] := "variabilă"; felDecl[4] := "procedură";
  felDecl[5] := "corp"; felDecl[6] := "text";
  fel[0] := "modul"; fel[1] := "constante"; fel[2] := "tip"; fel[3] := "variabile"; fel[4] := "procedură";
  fel[5] := "corpul modulului"; fel[6] := "text";
  rolNume[0] := ""; rolNume[1] := "procedură"; rolNume[2] := "tip"; rolNume[3] := "constantă"; rolNume[4] := "variabilă";
  rolNume[5] := "modul"; rolNume[6] := "raport";
  U("procedura"); U("procedurii"); U("functia"); U("functiei"); U("modulul"); U("modulului"); U("tipul"); U("tipului");
  U("constanta"); U("variabila"); U("cuvantul"); U("lui"); U("lu"); U("pe"); U("cu"); U("de"); U("despre"); U("codul");
  U("numele"); U("comanda")
END Motor.
