MODULE Lectii; (* Eula Oberon: lectiile. Oberon de la nivelul -1 (ce e un program) la 7 (citesti codul altora).
  Fiecare lectie: explicatie, exemplu, exercitiu. Exercitiul se verifica de doua ori: intai gramatica (Verifica),
  apoi daca ai facut ce cerea lectia. Unde a ramas Pion se tine minte in lectii.bin.
  In sirurile de mai jos ` tine locul ghilimelelor (Oberon nu le poate pune intr-un sir). *)

  IMPORT Litere, Iesire, Gramatica, Disc;

  CONST N = 9; MAGIC = 4C454354H;   (* lectiile -1..7 au indicii 0..8 *)

  VAR curenta*: INTEGER;              (* indicele lectiei deschise, -1 = niciuna *)
    trecut: ARRAY N OF BOOLEAN;
    titlu: ARRAY N OF ARRAY 48 OF CHAR;
    cale: ARRAY 1024 OF CHAR;

  (* ---------- scris ---------- *)

  PROCEDURE T(s: ARRAY OF CHAR);      (* text; ` devine ghilimele *)
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO IF s[i] = "`" THEN Iesire.C(22X) ELSE Iesire.C(s[i]) END ; INC(i) END
  END T;

  PROCEDURE Ln; BEGIN Iesire.C(0AX) END Ln;

  PROCEDURE Cod0; BEGIN Iesire.TGol END Cod0;

  PROCEDURE K(s: ARRAY OF CHAR);      (* un rand de cod *)
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO IF s[i] = "`" THEN Iesire.TC(22X) ELSE Iesire.TC(s[i]) END ; INC(i) END ;
    Iesire.TC(0AX)
  END K;

  PROCEDURE Cod1; BEGIN Iesire.CodT(1000) END Cod1;

  PROCEDURE Numar(i: INTEGER);        (* numarul lectiei, de la -1 *)
  BEGIN Iesire.Int(i - 1)
  END Numar;

  (* ---------- tinut minte ---------- *)

  PROCEDURE Salveaza;
    VAR i: INTEGER; tmp: ARRAY 1100 OF CHAR; ok: BOOLEAN;
  BEGIN
    IF cale[0] # 0X THEN
      Litere.Copy(cale, tmp); Litere.Add(tmp, ".tmp");
      IF Disc.Scrie(tmp) THEN
        Disc.PuneInt(MAGIC); Disc.PuneInt(curenta);
        FOR i := 0 TO N - 1 DO Disc.PuneBool(trecut[i]) END ;
        Disc.Inchide;
        IF Disc.ok THEN ok := Disc.Redenumeste(tmp, cale) END
      END
    END
  END Salveaza;

  PROCEDURE Incarca*(f: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN Litere.Copy(f, cale);
    IF Disc.Citeste(f) & (Disc.IaInt() = MAGIC) THEN
      curenta := Disc.IaInt();
      FOR i := 0 TO N - 1 DO trecut[i] := Disc.IaBool() END ;
      IF ~Disc.ok OR (curenta < -1) OR (curenta >= N) THEN curenta := -1 END
    END ;
    Disc.Inchide
  END Incarca;

  (* ---------- lectiile ---------- *)

  PROCEDURE L0;   (* -1 *)
  BEGIN
    T("Un program e o listă de pași pe care calculatorul îi face exact în ordinea în care sunt scriși. Nu ghicește nimic și nu sare peste nimic. ");
    T("Seamănă cu fișa de lucru la o cameră: întâi șpaclu, apoi șlefuiești, apoi grund, apoi două straturi de vopsea. Dacă inversezi pașii, iese prost; la fel și în cod."); Ln; Ln;
    T("În orice program găsești trei lucruri:"); Ln;
    T("1. Instrucțiuni: pașii („scrie pe ecran”, „adună”)."); Ln;
    T("2. Date: lucrurile cu care lucrezi (câți metri pătrați are peretele, câtă vopsea mai e în găleată)."); Ln;
    T("3. Decizii și repetări: „dacă peretele e umed, aștept”, „dau cu trafaletul până acoperă”."); Ln; Ln;
    T("Oberon e limba în care scriem pașii. Calculatorul nu o înțelege direct: un compilator o traduce în instrucțiuni pentru procesor. Eu am unul înăuntru: oberonc, și el scris în Oberon. ");
    T("Eu verific dacă ce scrii respectă gramatica limbii, ca un diriginte de șantier care se uită dacă fișa e completată corect. ");
    T("Dacă programul face ce voiai, asta se vede abia când îl rulezi: butonul Rulează îl compilează și îl pornește, iar ce scrie apare aici."); Ln; Ln;
    T("Lecția asta n-are exercițiu. Scrie „următoarea” când ești gata.")
  END L0;

  PROCEDURE L1;   (* 0 *)
  BEGIN
    T("În Oberon, orice program stă într-un modul. Modulul are un nume și se închide cu același nume, urmat de punct:"); Ln;
    Cod0; K("MODULE Salut;"); K("END Salut."); Cod1; Ln;
    T("Regulile:"); Ln;
    T("· MODULE și END se scriu cu majuscule: sunt cuvinte rezervate, cuvintele limbii."); Ln;
    T("· Numele îl alegi tu: litere și cifre, fără spații, începe cu o literă."); Ln;
    T("· După numele de sus vine „;”, după cel de jos vine „.”."); Ln;
    T("· Literele mari și mici contează: Salut și salut sunt nume diferite."); Ln; Ln;
    T("Exercițiu: scrie un modul gol cu numele tău (de exemplu MODULE Pion;), lipește-l în căsuță și apasă Verifică.")
  END L1;

  PROCEDURE L2;   (* 1 *)
  BEGIN
    T("Un modul gol nu face nimic. Ca să facă ceva, îi dai instrucțiuni între BEGIN și END. ");
    T("Ca să scrie pe ecran, folosim modulul Out (îl au toate compilatoarele, și al meu). Îl ceri cu IMPORT Out; și apoi îl folosești scriind Out. în fața procedurii: ");
    T("e ca atunci când iei o unealtă de la un coleg și spui a cui e, „trafaletul lui Ion”."); Ln;
    T("· Out.String(`text`) scrie textul dintre ghilimele."); Ln;
    T("· Out.Ln trece la rând nou."); Ln;
    T("· Instrucțiunile se despart cu „;”."); Ln;
    Cod0; K("MODULE Salut;"); K("  IMPORT Out;"); K("BEGIN"); K("  Out.String(`Salut, lume!`); Out.Ln"); K("END Salut."); Cod1; Ln;
    T("Exercițiu: scrie un modul care afișează două rânduri, numele tău și meseria ta. Apasă Verifică, apoi Rulează ca să vezi ce scrie.")
  END L2;

  PROCEDURE L3;   (* 2 *)
  BEGIN
    T("O variabilă e o cutie cu nume în care ții o valoare, ca o găleată pe care scrii „alb” ca să știi ce e în ea. ");
    T("Variabilele se declară în secțiunea VAR, împreună cu tipul lor:"); Ln;
    T("· INTEGER: numere întregi (3, 120, -5)"); Ln;
    T("· REAL: numere cu virgulă (2.5)"); Ln;
    T("· CHAR: o singură literă; BOOLEAN: adevărat sau fals"); Ln; Ln;
    T("Pui o valoare în cutie cu „:=” (se citește „primește”). „=” e comparație, nu atribuire. ");
    T("Out.Int(x, 0) scrie un număr; 0 înseamnă fără spații în față."); Ln;
    Cod0; K("MODULE Camera;"); K("  IMPORT Out;"); K("  VAR lungime, latime, arie: INTEGER;"); K("BEGIN");
    K("  lungime := 4; latime := 3;"); K("  arie := lungime * latime;"); K("  Out.String(`Aria: `); Out.Int(arie, 0); Out.Ln"); K("END Camera."); Cod1; Ln;
    T("Exercițiu: calculează câți litri de vopsea trebuie pentru un perete. Un litru acoperă cam 10 m², deci litri = arie DIV 10 ");
    T("(DIV e împărțirea fără zecimale). Afișează rezultatul cu Out.Int.")
  END L3;

  PROCEDURE L4;   (* 3 *)
  BEGIN
    T("Uneori programul trebuie să aleagă. Pentru asta e IF:"); Ln;
    Cod0; K("IF conditie THEN"); K("  (* ce faci daca e adevarat *)"); K("ELSE"); K("  (* ce faci altfel *)"); K("END"); Cod1; Ln;
    T("Condițiile compară: = (egal), # (diferit), <, >, <=, >=. Le poți lega cu & (și), OR (sau), ~ (nu). ");
    T("Ce scrii între (* și *) e un comentariu: o notă pentru oameni, pe care calculatorul o sare."); Ln;
    Cod0; K("IF umiditate > 70 THEN"); K("  Out.String(`Astept sa se usuce`)"); K("ELSE"); K("  Out.String(`Pot vopsi`)"); K("END"); Cod1; Ln;
    T("Exercițiu: un modul cu o variabilă straturi. Dă-i o valoare, apoi: dacă straturi < 2, scrie „Mai dau un strat”, altfel scrie „Gata”.")
  END L4;

  PROCEDURE L5;   (* 4 *)
  BEGIN
    T("Ca să repeți un pas, ai două feluri:"); Ln;
    T("· FOR numără: FOR i := 1 TO 3 DO … END face pașii de 3 ori, cu i = 1, 2, 3."); Ln;
    T("· WHILE repetă cât timp o condiție e adevărată, cum ai da cu trafaletul cât timp se mai vede peretele vechi. ");
    T("Ai grijă ca ceva să se schimbe înăuntru, altfel nu se mai oprește. INC(x) adaugă 1 la x."); Ln;
    Cod0; K("FOR strat := 1 TO 3 DO"); K("  Out.String(`Stratul `); Out.Int(strat, 0); Out.Ln"); K("END"); Cod1; Ln;
    Cod0; K("i := 1;"); K("WHILE i <= 3 DO"); K("  Out.Int(i, 0); Out.Ln; INC(i)"); K("END"); Cod1; Ln;
    T("Exercițiu: scrie un modul care afișează numerele de la 1 la 5, câte unul pe rând, cu FOR sau cu WHILE.")
  END L5;

  PROCEDURE L6;   (* 5 *)
  BEGIN
    T("O procedură e o unealtă pe care ți-o faci singur: o declari o dată și o folosești de câte ori vrei. ");
    T("Parametrii sunt ce îi dai uneltei. O procedură care dă un rezultat înapoi (o funcție) are tipul rezultatului după paranteze și RETURN la sfârșit:"); Ln;
    Cod0; K("MODULE Calcul;"); K("  IMPORT Out;"); K(""); K("  PROCEDURE Arie(lungime, inaltime: INTEGER): INTEGER;");
    K("  BEGIN"); K("    RETURN lungime * inaltime"); K("  END Arie;"); K(""); K("BEGIN"); K("  Out.Int(Arie(4, 3), 0); Out.Ln"); K("END Calcul."); Cod1; Ln;
    T("Procedurile stau între declarații și BEGIN-ul modulului, iar fiecare se închide cu END și numele ei. ");
    T("În Oberon-07, RETURN apare o singură dată, chiar înainte de END."); Ln; Ln;
    T("Exercițiu: scrie o procedură Litri(arie: INTEGER): INTEGER care întoarce arie DIV 10. Apoi folosește-o în corpul modulului ca să afișezi câți litri trebuie pentru 35 m².")
  END L6;

  PROCEDURE L7;   (* 6 *)
  BEGIN
    T("Când ai mai multe lucruri de același fel, le ții împreună:"); Ln;
    T("· ARRAY 4 OF INTEGER înseamnă patru cutii la rând, numerotate de la 0: perete[0], perete[1], perete[2], perete[3]."); Ln;
    T("· RECORD grupează câmpuri cu nume diferite, ca o fișă: TYPE Perete = RECORD lungime, inaltime: INTEGER END;"); Ln;
    Cod0; K("MODULE Camera;"); K("  IMPORT Out;"); K("  VAR arie: ARRAY 4 OF INTEGER; i, total: INTEGER;"); K("BEGIN");
    K("  arie[0] := 12; arie[1] := 9; arie[2] := 12; arie[3] := 9;"); K("  total := 0;"); K("  FOR i := 0 TO 3 DO total := total + arie[i] END ;");
    K("  Out.String(`Total: `); Out.Int(total, 0); Out.Ln"); K("END Camera."); Cod1; Ln;
    T("Exercițiu: pune într-un ARRAY ariile pereților unei camere ale tale și adună-le cu un FOR (sau WHILE).")
  END L7;

  PROCEDURE L8;   (* 7 *)
  BEGIN
    T("Ai acum tot ce trebuie ca să citești codul altora, iar eu am în memorie peste 800 de module. Întreabă-mă, de exemplu:"); Ln;
    T("· „ce exportă Texts”: ce unelte dă un modul"); Ln;
    T("· „arată Texts.WriteString”: cum e făcută o unealtă"); Ln;
    T("· „cum folosesc Files.Old”: cum o folosesc alții"); Ln;
    T("· „ce este WHILE”, „regula IfStatement”: cuvintele și regulile limbii"); Ln; Ln;
    T("Exercițiu de final: scrie un modul al tău care are o procedură, un IF și o buclă (FOR sau WHILE), și care trece ca Oberon-07 curat, fără extensii Oberon-2.")
  END L8;

  PROCEDURE Arata(i: INTEGER);
  BEGIN
    T("Lecția "); Numar(i); T(" · "); T(titlu[i]); Ln; Ln;
    CASE i OF
      0: L0 | 1: L1 | 2: L2 | 3: L3 | 4: L4 | 5: L5 | 6: L6 | 7: L7 | 8: L8
    END ;
    Ln; Ln; T("(„indiciu” dacă te blochezi, „soluția” ca s-o vezi, „lecții” pentru listă)")
  END Arata;

  PROCEDURE Indiciu(i: INTEGER);
  BEGIN
    CASE i OF
      0: T("Lecția -1 n-are exercițiu. Scrie „următoarea”.")
    | 1: T("Două rânduri: MODULE și un nume, urmat de „;”; apoi END, același nume și „.”.")
    | 2: T("Ai nevoie de IMPORT Out; după prima linie, de BEGIN, apoi de două Out.String(…) urmate de Out.Ln, despărțite cu „;”.")
    | 3: T("Declară VAR arie, litri: INTEGER; după IMPORT. În corp: arie := …; litri := arie DIV 10; apoi Out.Int(litri, 0).")
    | 4: T("Structura: IF straturi < 2 THEN Out.String(…) ELSE Out.String(…) END. Nu uita să-i dai întâi o valoare: straturi := 1;")
    | 5: T("FOR i := 1 TO 5 DO Out.Int(i, 0); Out.Ln END. Variabila i trebuie declarată în VAR.")
    | 6: T("Procedura se scrie înainte de BEGIN-ul modulului: PROCEDURE Litri(arie: INTEGER): INTEGER; BEGIN RETURN arie DIV 10 END Litri; Apoi, în corp: Out.Int(Litri(35), 0).")
    | 7: T("VAR arie: ARRAY 4 OF INTEGER; … arie[0] := …; și un FOR i := 0 TO 3 DO total := total + arie[i] END.")
    | 8: T("Pune cap la cap lecțiile 4, 5 și 6: o procedură, iar în corp un FOR care o cheamă și un IF.")
    END
  END Indiciu;

  PROCEDURE Solutia(i: INTEGER);
  BEGIN Cod0;
    CASE i OF
      0: K("(* nimic de scris aici *)")
    | 1: K("MODULE Pion;"); K("END Pion.")
    | 2: K("MODULE Eu;"); K("  IMPORT Out;"); K("BEGIN"); K("  Out.String(`Pion`); Out.Ln;"); K("  Out.String(`Zugrav`); Out.Ln"); K("END Eu.")
    | 3: K("MODULE Vopsea;"); K("  IMPORT Out;"); K("  VAR arie, litri: INTEGER;"); K("BEGIN"); K("  arie := 4 * 3;"); K("  litri := arie DIV 10;");
         K("  Out.String(`Litri: `); Out.Int(litri, 0); Out.Ln"); K("END Vopsea.")
    | 4: K("MODULE Straturi;"); K("  IMPORT Out;"); K("  VAR straturi: INTEGER;"); K("BEGIN"); K("  straturi := 1;");
         K("  IF straturi < 2 THEN Out.String(`Mai dau un strat`) ELSE Out.String(`Gata`) END ;"); K("  Out.Ln"); K("END Straturi.")
    | 5: K("MODULE Numere;"); K("  IMPORT Out;"); K("  VAR i: INTEGER;"); K("BEGIN"); K("  FOR i := 1 TO 5 DO Out.Int(i, 0); Out.Ln END"); K("END Numere.")
    | 6: K("MODULE Calcul;"); K("  IMPORT Out;"); K(""); K("  PROCEDURE Litri(arie: INTEGER): INTEGER;"); K("  BEGIN"); K("    RETURN arie DIV 10");
         K("  END Litri;"); K(""); K("BEGIN"); K("  Out.Int(Litri(35), 0); Out.Ln"); K("END Calcul.")
    | 7: K("MODULE Camera;"); K("  IMPORT Out;"); K("  VAR arie: ARRAY 4 OF INTEGER; i, total: INTEGER;"); K("BEGIN");
         K("  arie[0] := 12; arie[1] := 9; arie[2] := 12; arie[3] := 9;"); K("  total := 0;");
         K("  FOR i := 0 TO 3 DO total := total + arie[i] END ;"); K("  Out.Int(total, 0); Out.Ln"); K("END Camera.")
    | 8: K("MODULE Santier;"); K("  IMPORT Out;"); K("  VAR p: INTEGER;"); K(""); K("  PROCEDURE Litri(arie: INTEGER): INTEGER;");
         K("  BEGIN"); K("    RETURN arie DIV 10"); K("  END Litri;"); K(""); K("BEGIN"); K("  FOR p := 10 TO 40 BY 10 DO");
         K("    IF Litri(p) < 2 THEN Out.String(`putin `) ELSE Out.String(`mult `) END ;"); K("    Out.Int(Litri(p), 0); Out.Ln"); K("  END"); K("END Santier.")
    END ;
    Cod1
  END Solutia;

  PROCEDURE Lista;
    VAR i: INTEGER;
  BEGIN T("Lecțiile (✓ = exercițiu trecut, ▸ = unde ai rămas):"); Ln;
    FOR i := 0 TO N - 1 DO
      IF i = curenta THEN T("▸ ") ELSIF trecut[i] THEN T("✓ ") ELSE T("· ") END ;
      Numar(i); T(". "); T(titlu[i]); Ln
    END ;
    T("Scrie „lecția 0” (sau oricare număr) ca să începi.")
  END Lista;

  (* ---------- comenzile ---------- *)

  PROCEDURE Norm(s: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR i, j: INTEGER; c: CHAR; sp: BOOLEAN;
  BEGIN Litere.Copy(s, d); Litere.MicFold(d); i := 0; j := 0; sp := FALSE;
    WHILE d[i] # 0X DO
      c := d[i];
      IF ~((c >= "a") & (c <= "z") OR (c >= "0") & (c <= "9") OR (c = "-")) THEN c := " " END ;
      IF c = " " THEN sp := TRUE ELSE IF sp & (j > 0) THEN d[j] := " "; INC(j) END ; sp := FALSE; d[j] := c; INC(j) END ;
      INC(i)
    END ;
    d[j] := 0X
  END Norm;

  PROCEDURE Deschide(i: INTEGER);
  BEGIN
    IF i < 0 THEN i := 0 END ;
    IF i >= N THEN T("Asta a fost ultima lecție. Mai departe, cel mai bun profesor e codul din memoria mea: întreabă-mă de orice modul.")
    ELSE curenta := i; Salveaza; Arata(i)
    END
  END Deschide;

  (* TRUE daca intrebarea era o comanda a lectiilor (raspunsul e in Iesire) *)
  PROCEDURE Comanda*(q: ARRAY OF CHAR): BOOLEAN;
    VAR f: ARRAY 256 OF CHAR; ok, neg: BOOLEAN; i, x: INTEGER;
  BEGIN Norm(q, f); ok := TRUE;
    IF (f = "lectii") OR (f = "lectiile") OR (f = "lectie") OR (f = "vreau sa invat") OR (f = "invata-ma") OR (f = "invata ma") OR (f = "invata-ma oberon") THEN Lista
    ELSIF Litere.Incepe(f, "lectia ") OR Litere.Incepe(f, "lectie ") OR Litere.Incepe(f, "nivelul ") THEN
      i := 0; WHILE f[i] # " " DO INC(i) END ; INC(i);
      neg := FALSE;
      IF f[i] = "-" THEN neg := TRUE; INC(i) ELSIF Litere.Incepe(f, "lectia minus ") THEN neg := TRUE; i := 13 END ;
      IF (f[i] >= "0") & (f[i] <= "9") THEN
        x := 0; WHILE (f[i] >= "0") & (f[i] <= "9") DO x := x * 10 + ORD(f[i]) - ORD("0"); INC(i) END ;
        IF neg THEN x := -x END ;
        IF (x < -1) OR (x > 7) THEN T("Am lecții de la -1 la 7. "); Lista ELSE Deschide(x + 1) END
      ELSE ok := FALSE
      END
    ELSIF (f = "urmatoarea") OR (f = "urmatoarea lectie") OR (f = "mai departe") OR (f = "next") OR (f = "inainte") THEN
      IF curenta < 0 THEN Deschide(0) ELSE Deschide(curenta + 1) END
    ELSIF (f = "din nou") OR (f = "repeta") OR (f = "repeta lectia") OR (f = "unde am ramas") THEN
      IF curenta < 0 THEN T("N-ai început încă. "); Lista ELSE Arata(curenta) END
    ELSIF (f = "indiciu") OR (f = "un indiciu") OR (f = "hint") THEN
      IF curenta < 0 THEN T("Întâi deschide o lecție: „lecția 0”.") ELSE Indiciu(curenta) END
    ELSIF (f = "solutia") OR (f = "solutie") OR (f = "rezolvarea") OR (f = "arata solutia") THEN
      IF curenta < 0 THEN T("Întâi deschide o lecție: „lecția 0”.")
      ELSE T("O soluție posibilă (sunt multe bune):"); Ln; Solutia(curenta); Ln;
        T("Încearcă s-o scrii tu, din memorie, și apasă Verifică.")
      END
    ELSE ok := FALSE
    END ;
    RETURN ok
  END Comanda;

  (* ---------- verificarea exercitiului ---------- *)

  PROCEDURE Are(VAR t: ARRAY OF CHAR; n: INTEGER; w: ARRAY OF CHAR): INTEGER;   (* de cate ori apare w ca un cuvant intreg *)
    VAR i, k, lw, c: INTEGER;
  BEGIN lw := Litere.Len(w); c := 0; i := 0;
    WHILE i + lw <= n DO
      IF (i = 0) OR ~Litere.Cuvant(t[i-1]) THEN
        k := 0; WHILE (k < lw) & (t[i+k] = w[k]) DO INC(k) END ;
        IF (k = lw) & ((i + lw = n) OR ~Litere.Cuvant(t[i+lw])) THEN INC(c) END
      END ;
      INC(i)
    END ;
    RETURN c
  END Are;

  PROCEDURE Contine(VAR t: ARRAY OF CHAR; n: INTEGER; w: ARRAY OF CHAR): BOOLEAN;   (* apare w oriunde *)
    VAR i, k, lw: INTEGER; r: BOOLEAN;
  BEGIN lw := Litere.Len(w); r := FALSE; i := 0;
    WHILE ~r & (i + lw <= n) DO
      k := 0; WHILE (k < lw) & (t[i+k] = w[k]) DO INC(k) END ;
      r := k = lw; INC(i)
    END ;
    RETURN r
  END Contine;

  PROCEDURE ImportaOut(): BOOLEAN;
    VAR i: INTEGER; r: BOOLEAN; m: ARRAY 64 OF CHAR;
  BEGIN r := FALSE;
    FOR i := 0 TO Gramatica.nimp - 1 DO Gramatica.Nume(Gramatica.impA[i], Gramatica.impN[i], m); IF m = "Out" THEN r := TRUE END END ;
    RETURN r
  END ImportaOut;

  PROCEDURE AreVar(): BOOLEAN;
    VAR i: INTEGER; r: BOOLEAN;
  BEGIN r := FALSE;
    FOR i := 0 TO Gramatica.nd - 1 DO IF (Gramatica.dKind[i] = Gramatica.KVar) & (Gramatica.dLevel[i] = 0) THEN r := TRUE END END ;
    RETURN r
  END AreVar;

  (* o procedura de la nivelul modulului, folosita si in alta parte decat in declaratia ei *)
  PROCEDURE ProceduraFolosita(VAR t: ARRAY OF CHAR; n: INTEGER; VAR are: BOOLEAN): BOOLEAN;
    VAR i: INTEGER; r: BOOLEAN; m: ARRAY 64 OF CHAR;
  BEGIN r := FALSE; are := FALSE;
    FOR i := 0 TO Gramatica.nd - 1 DO
      IF (Gramatica.dKind[i] = Gramatica.KProc) & (Gramatica.dLevel[i] = 0) THEN
        are := TRUE; Gramatica.Nume(Gramatica.dNameA[i], Gramatica.dNameN[i], m);
        IF Are(t, n, m) >= 3 THEN r := TRUE END
      END
    END ;
    RETURN r
  END ProceduraFolosita;

  PROCEDURE Lipsa(VAR primul: BOOLEAN; s: ARRAY OF CHAR);
  BEGIN
    IF primul THEN T("Pentru exercițiul lecției "); Numar(curenta); T(" mai lipsește:"); primul := FALSE END ;
    Ln; T("· "); T(s)
  END Lipsa;

  (* dupa Verifica: daca e deschisa o lectie, spune daca exercitiul e facut *)
  PROCEDURE DupaVerificare*(VAR t: ARRAY OF CHAR; n: INTEGER);
    VAR primul, areProc: BOOLEAN;
  BEGIN
    IF (curenta >= 1) & (curenta < N) THEN
      Ln; Ln; primul := TRUE;
      IF ~Gramatica.ok THEN T("Întâi repară greșeala de mai sus; apoi verific și exercițiul lecției "); Numar(curenta); T(".")
      ELSIF Gramatica.fel # 0 THEN T("Pentru exercițiu, scrie un modul întreg: MODULE Nume; … END Nume.")
      ELSE
        CASE curenta OF
          1: (* doar un modul corect *)
        | 2: IF ~ImportaOut() THEN Lipsa(primul, "IMPORT Out; (fără el nu poți scrie pe ecran)") END ;
             IF Are(t, n, "BEGIN") = 0 THEN Lipsa(primul, "BEGIN: instrucțiunile stau între BEGIN și END") END ;
             IF Are(t, n, "String") < 2 THEN Lipsa(primul, "două Out.String(…): numele și meseria") END ;
             IF Are(t, n, "Ln") = 0 THEN Lipsa(primul, "Out.Ln, ca să treci la rând nou") END
        | 3: IF ~AreVar() THEN Lipsa(primul, "o secțiune VAR cu variabilele (de exemplu VAR arie, litri: INTEGER;)") END ;
             IF ~Contine(t, n, ":=") THEN Lipsa(primul, "o atribuire cu := (de exemplu arie := 12)") END ;
             IF Are(t, n, "DIV") = 0 THEN Lipsa(primul, "DIV pentru împărțire (litri := arie DIV 10)") END ;
             IF Are(t, n, "Int") = 0 THEN Lipsa(primul, "Out.Int(…, 0) ca să afișezi numărul") END
        | 4: IF Are(t, n, "IF") = 0 THEN Lipsa(primul, "un IF … THEN … END") END ;
             IF Are(t, n, "ELSE") = 0 THEN Lipsa(primul, "ramura ELSE (ce faci altfel)") END ;
             IF ~Contine(t, n, ":=") THEN Lipsa(primul, "o valoare pentru variabilă (straturi := 1)") END
        | 5: IF (Are(t, n, "FOR") = 0) & (Are(t, n, "WHILE") = 0) THEN Lipsa(primul, "o buclă: FOR … DO … END sau WHILE … DO … END") END ;
             IF Are(t, n, "Int") = 0 THEN Lipsa(primul, "Out.Int ca să scrii numerele") END
        | 6: IF ~ProceduraFolosita(t, n, areProc) THEN
               IF ~areProc THEN Lipsa(primul, "o procedură (PROCEDURE Litri(arie: INTEGER): INTEGER; …)")
               ELSE Lipsa(primul, "să și folosești procedura în corpul modulului, după BEGIN")
               END
             END ;
             IF Are(t, n, "RETURN") = 0 THEN Lipsa(primul, "RETURN, ca procedura să dea rezultatul înapoi") END
        | 7: IF Are(t, n, "ARRAY") = 0 THEN Lipsa(primul, "un ARRAY (de exemplu VAR arie: ARRAY 4 OF INTEGER;)") END ;
             IF ~Contine(t, n, "[") THEN Lipsa(primul, "să folosești căsuțele tabloului: arie[0], arie[i]") END ;
             IF (Are(t, n, "FOR") = 0) & (Are(t, n, "WHILE") = 0) THEN Lipsa(primul, "o buclă care le adună") END
        | 8: IF ~ProceduraFolosita(t, n, areProc) THEN Lipsa(primul, "o procedură a ta, folosită în corp") END ;
             IF Are(t, n, "IF") = 0 THEN Lipsa(primul, "un IF") END ;
             IF (Are(t, n, "FOR") = 0) & (Are(t, n, "WHILE") = 0) THEN Lipsa(primul, "o buclă (FOR sau WHILE)") END ;
             IF Gramatica.no2 > 0 THEN Lipsa(primul, "să fie Oberon-07 curat (fără LOOP, EXIT, WITH sau RETURN în mijloc)") END
        END ;
        IF primul THEN
          trecut[curenta] := TRUE; Salveaza;
          T("✓ Exercițiul lecției "); Numar(curenta); T(" e făcut.");
          IF curenta < N - 1 THEN T(" Scrie „următoarea” pentru lecția "); Numar(curenta + 1); T(".")
          ELSE T(" Ai terminat lecțiile. De aici încolo, codul din memoria mea e manualul tău.")
          END
        END
      END
    END
  END DupaVerificare;

BEGIN curenta := -1; cale := "";
  titlu[0] := "Ce e un program"; titlu[1] := "Primul modul"; titlu[2] := "Să spună ceva"; titlu[3] := "Cutii cu nume (variabile)";
  titlu[4] := "Dacă (IF)"; titlu[5] := "Repetă (FOR, WHILE)"; titlu[6] := "Unelte proprii (proceduri)";
  titlu[7] := "Grupuri (ARRAY, RECORD)"; titlu[8] := "Citește codul altora"
END Lectii.
