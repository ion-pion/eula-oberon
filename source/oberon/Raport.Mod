MODULE Raport; (* Eula Oberon: ce stie din nastere — sintaxa din raportul Oberon-07 (regulile EBNF, ca in apendicele
  lui Wirth), un glosar in romana al cuvintelor limbii si un mic dictionar roman -> englez pentru intrebarile puse in
  romana despre cod scris in engleza. In sirurile de mai jos ` tine locul ghilimelelor si ¶ al randului nou. *)

  IMPORT Litere;

  CONST MaxP = 60000; MaxR = 64; MaxF = 48; MaxG = 80; MaxK = 200; MaxE = 128;

  VAR pool: ARRAY MaxP OF CHAR; np: INTEGER;
    nr*: INTEGER; rA, rN: ARRAY MaxR OF INTEGER;
    nf: INTEGER; fCuv, fReg: ARRAY MaxF OF ARRAY 24 OF CHAR;
    ng: INTEGER; gA, gN: ARRAY MaxG OF INTEGER;
    nk: INTEGER; kNume: ARRAY MaxK OF ARRAY 24 OF CHAR; kG: ARRAY MaxK OF INTEGER;
    ne: INTEGER; ePre: ARRAY MaxE OF ARRAY 16 OF CHAR; eCuv: ARRAY MaxE OF ARRAY 48 OF CHAR;
    nen*: INTEGER; en*: ARRAY 8 OF ARRAY 24 OF CHAR;

  PROCEDURE Pune(s: ARRAY OF CHAR; VAR a, n: INTEGER);
    VAR i: INTEGER; c: CHAR;
  BEGIN a := np; i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO
      c := s[i];
      IF c = "`" THEN c := 22X ELSIF c = "¶" THEN c := 0AX END ;
      IF np < MaxP THEN pool[np] := c; INC(np) END ;
      INC(i)
    END ;
    n := np - a
  END Pune;

  PROCEDURE Ia(a, n: INTEGER; VAR d: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < n) & (i < LEN(d) - 1) DO d[i] := pool[a + i]; INC(i) END ;
    d[i] := 0X
  END Ia;

  PROCEDURE R(s: ARRAY OF CHAR);
  BEGIN Pune(s, rA[nr], rN[nr]); INC(nr)
  END R;

  PROCEDURE F(cuv, reg: ARRAY OF CHAR);
  BEGIN fCuv[nf] := cuv; fReg[nf] := reg; INC(nf)
  END F;

  PROCEDURE G(chei, text: ARRAY OF CHAR);
    VAR i, j: INTEGER;
  BEGIN Pune(text, gA[ng], gN[ng]); i := 0;
    WHILE (i < LEN(chei)) & (chei[i] # 0X) DO
      j := 0;
      WHILE (i < LEN(chei)) & (chei[i] # 0X) & (chei[i] # "|") DO kNume[nk][j] := chei[i]; INC(j); INC(i) END ;
      kNume[nk][j] := 0X; kG[nk] := ng; INC(nk);
      IF (i < LEN(chei)) & (chei[i] = "|") THEN INC(i) END
    END ;
    INC(ng)
  END G;

  PROCEDURE GA(text: ARRAY OF CHAR);                  (* continuarea ultimului text (sirurile constante au cel mult 255 de semne) *)
    VAR a, n: INTEGER;
  BEGIN Pune(text, a, n); gN[ng - 1] := gN[ng - 1] + n
  END GA;

  PROCEDURE E(pre, cuv: ARRAY OF CHAR);
  BEGIN ePre[ne] := pre; eCuv[ne] := cuv; INC(ne)
  END E;

  (* ---------- regulile ---------- *)

  PROCEDURE RegulaText*(i: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN Ia(rA[i], rN[i], d)
  END RegulaText;

  PROCEDURE RegulaNume*(i: INTEGER; VAR d: ARRAY OF CHAR);
    VAR j: INTEGER;
  BEGIN j := 0;
    WHILE (j < rN[i]) & (pool[rA[i] + j] # " ") & (j < LEN(d) - 1) DO d[j] := pool[rA[i] + j]; INC(j) END ;
    d[j] := 0X
  END RegulaNume;

  PROCEDURE Cauta(c: ARRAY OF CHAR): INTEGER;      (* regula cu numele c (litere mici) *)
    VAR i, r: INTEGER; nume: ARRAY 64 OF CHAR;
  BEGIN r := -1; i := 0;
    WHILE (r < 0) & (i < nr) DO
      RegulaNume(i, nume); Litere.MicS(nume);
      IF nume = c THEN r := i END ;
      INC(i)
    END ;
    RETURN r
  END Cauta;

  PROCEDURE Regula*(cuvant: ARRAY OF CHAR; VAR d: ARRAY OF CHAR): BOOLEAN;
    VAR c, x: ARRAY 64 OF CHAR; i, r: INTEGER;
  BEGIN Litere.Copy(cuvant, c); Litere.MicS(c); r := Cauta(c); i := 0;
    WHILE (r < 0) & (i < nf) DO
      IF fCuv[i] = c THEN Litere.Copy(fReg[i], x); Litere.MicS(x); r := Cauta(x) END ;
      INC(i)
    END ;
    IF r >= 0 THEN RegulaText(r, d) ELSE d[0] := 0X END ;
    RETURN r >= 0
  END Regula;

  (* ---------- glosarul ---------- *)

  PROCEDURE Cheie(c: ARRAY OF CHAR; VAR d: ARRAY OF CHAR): BOOLEAN;
    VAR i, r: INTEGER;
  BEGIN r := -1; i := 0;
    WHILE (r < 0) & (i < nk) DO IF kNume[i] = c THEN r := kG[i] END ; INC(i) END ;
    IF r >= 0 THEN Ia(gA[r], gN[r], d) END ;
    RETURN r >= 0
  END Cheie;

  PROCEDURE Glosar*(cuvant: ARRAY OF CHAR; VAR d: ARRAY OF CHAR): BOOLEAN;
    VAR c, x: ARRAY 128 OF CHAR; ok: BOOLEAN; i, n: INTEGER;
  BEGIN Litere.Copy(cuvant, c); Litere.MicS(c); Litere.FoldS(c); Litere.Trim(c);
    ok := Cheie(c, d);
    IF ~ok THEN
      Litere.Copy(c, x); i := 0;
      WHILE x[i] # 0X DO IF x[i] = " " THEN x[i] := "-" END ; INC(i) END ;
      ok := Cheie(x, d)
    END ;
    n := Litere.Len(c);
    IF ~ok & (n > 4) & Litere.Sfarsit(c, "ul") THEN Litere.Sub(c, 0, n - 2, x); ok := Cheie(x, d) END ;
    IF ~ok & (n > 4) & Litere.Sfarsit(c, "a") THEN Litere.Sub(c, 0, n - 1, x); ok := Cheie(x, d) END ;
    RETURN ok
  END Glosar;

  (* ---------- romana -> engleza ---------- *)

  PROCEDURE Engleza*(cuvant: ARRAY OF CHAR);
    VAR f: ARRAY 64 OF CHAR; i, best, j, k: INTEGER;
  BEGIN Litere.Copy(cuvant, f); Litere.MicFold(f); nen := 0; best := -1;
    FOR i := 0 TO ne - 1 DO
      IF Litere.Incepe(f, ePre[i]) & ((best < 0) OR (Litere.Len(ePre[i]) > Litere.Len(ePre[best]))) THEN best := i END
    END ;
    IF best >= 0 THEN
      FOR i := 0 TO ne - 1 DO
        IF ePre[i] = ePre[best] THEN
          j := 0;
          WHILE eCuv[i][j] # 0X DO
            k := 0;
            WHILE (eCuv[i][j] # 0X) & (eCuv[i][j] # " ") DO IF (nen < 8) & (k < 23) THEN en[nen][k] := eCuv[i][j]; INC(k) END ; INC(j) END ;
            IF nen < 8 THEN en[nen][k] := 0X; INC(nen) END ;
            IF eCuv[i][j] = " " THEN INC(j) END
          END
        END
      END
    END
  END Engleza;

BEGIN np := 0; nr := 0; nf := 0; ng := 0; nk := 0; ne := 0;
  R("ident = letter {letter | digit}.");
  R("qualident = [ident `.`] ident.");
  R("identdef = ident [`*`].");
  R("integer = digit {digit} | digit {hexDigit} `H`.");
  R("real = digit {digit} `.` {digit} [ScaleFactor].");
  R("ScaleFactor = (`E` | `D`) [`+` | `-`] digit {digit}.");
  R("number = integer | real.");
  R("string = ``` {character} ``` | digit {hexDigit} `X`.");
  R("ConstDeclaration = identdef `=` ConstExpression.");
  R("ConstExpression = expression.");
  R("TypeDeclaration = identdef `=` StrucType.");
  R("StrucType = ArrayType | RecordType | PointerType | ProcedureType.");
  R("type = qualident | StrucType.");
  R("ArrayType = ARRAY length {`,` length} OF type.");
  R("length = ConstExpression.");
  R("RecordType = RECORD [`(` BaseType `)`] [FieldListSequence] END.");
  R("BaseType = qualident.");
  R("FieldListSequence = FieldList {`;` FieldList}.");
  R("FieldList = IdentList `:` type.");
  R("IdentList = identdef {`,` identdef}.");
  R("PointerType = POINTER TO type.");
  R("ProcedureType = PROCEDURE [FormalParameters].");
  R("VariableDeclaration = IdentList `:` type.");
  R("expression = SimpleExpression [relation SimpleExpression].");
  R("relation = `=` | `#` | `<` | `<=` | `>` | `>=` | IN | IS.");
  R("SimpleExpression = [`+` | `-`] term {AddOperator term}.");
  R("AddOperator = `+` | `-` | OR.");
  R("term = factor {MulOperator factor}.");
  R("MulOperator = `*` | `/` | DIV | MOD | `&`.");
  R("factor = number | string | NIL | TRUE | FALSE | set | designator [ActualParameters] | `(` expression `)` | `~` factor.");
  R("designator = qualident {selector}.");
  R("selector = `.` ident | `[` ExpList `]` | `^` | `(` qualident `)`.");
  R("set = `{` [element {`,` element}] `}`.");
  R("element = expression [`..` expression].");
  R("ExpList = expression {`,` expression}.");
  R("ActualParameters = `(` [ExpList] `)`.");
  R("statement = [assignment | ProcedureCall | IfStatement | CaseStatement | WhileStatement | RepeatStatement | ForStatement].");
  R("assignment = designator `:=` expression.");
  R("ProcedureCall = designator [ActualParameters].");
  R("StatementSequence = statement {`;` statement}.");
  R("IfStatement = IF expression THEN StatementSequence {ELSIF expression THEN StatementSequence} [ELSE StatementSequence] END.");
  R("CaseStatement = CASE expression OF case {`|` case} END.");
  R("case = [CaseLabelList `:` StatementSequence].");
  R("CaseLabelList = LabelRange {`,` LabelRange}.");
  R("LabelRange = label [`..` label].");
  R("label = integer | string | qualident.");
  R("WhileStatement = WHILE expression DO StatementSequence {ELSIF expression DO StatementSequence} END.");
  R("RepeatStatement = REPEAT StatementSequence UNTIL expression.");
  R("ForStatement = FOR ident `:=` expression TO expression [BY ConstExpression] DO StatementSequence END.");
  R("ProcedureDeclaration = ProcedureHeading `;` ProcedureBody ident.");
  R("ProcedureHeading = PROCEDURE identdef [FormalParameters].");
  R("ProcedureBody = DeclarationSequence [BEGIN StatementSequence] [RETURN expression] END.");
  R("DeclarationSequence = [CONST {ConstDeclaration `;`}] [TYPE {TypeDeclaration `;`}] [VAR {VariableDeclaration `;`}] {ProcedureDeclaration `;`}.");
  R("FormalParameters = `(` [FPSection {`;` FPSection}] `)` [`:` qualident].");
  R("FPSection = [VAR] ident {`,` ident} `:` FormalType.");
  R("FormalType = {ARRAY OF} qualident.");
  R("module = MODULE ident `;` [ImportList] DeclarationSequence [BEGIN StatementSequence] END ident `.`.");
  R("ImportList = IMPORT import {`,` import} `;`.");
  R("import = ident [`:=` ident].");
  F("if", "IfStatement");
  F("elsif", "IfStatement");
  F("then", "IfStatement");
  F("daca", "IfStatement");
  F("case", "CaseStatement");
  F("while", "WhileStatement");
  F("repeat", "RepeatStatement");
  F("until", "RepeatStatement");
  F("for", "ForStatement");
  F("module", "module");
  F("modul", "module");
  F("import", "ImportList");
  F("procedure", "ProcedureDeclaration");
  F("procedura", "ProcedureDeclaration");
  F("return", "ProcedureBody");
  F("array", "ArrayType");
  F("tablou", "ArrayType");
  F("record", "RecordType");
  F("inregistrare", "RecordType");
  F("pointer", "PointerType");
  F("const", "ConstDeclaration");
  F("constanta", "ConstDeclaration");
  F("type", "TypeDeclaration");
  F("tip", "type");
  F("var", "VariableDeclaration");
  F("variabila", "VariableDeclaration");
  F("atribuire", "assignment");
  F("expresie", "expression");
  F("instructiune", "statement");
  F("set", "set");
  F("multime", "set");
  F("parametri", "FormalParameters");
  F("parametru", "FPSection");
  F("sir", "string");
  F("numar", "number");
  F("nume", "ident");
  F("identificator", "ident");
  G("module|modul", "MODULE e unitatea de compilare în Oberon. Un modul are un nume, își spune importurile, apoi constantele, tipurile, variabilele și procedurile, și poate avea un corp (BEGIN … END Nu");
    GA("me.) care rulează o singură dată, când modulul e încărcat. Ce e marcat cu * se exportă.¶¶MODULE Salut;¶  IMPORT Out;¶BEGIN Out.String(`Salut`); Out.Ln¶END Salut.");
  G("import", "IMPORT spune ce module folosește modulul. Numele luate de acolo se scriu cu numele modulului în față: Texts.Write. Se poate da și un alt nume: IMPORT T := Texts.");
  G("const|constanta|constante", "CONST declară constante: nume = expresie calculată la compilare.¶¶CONST N = 100; Pi = 3.14159; Mesaj = `gata`;");
  G("type|tip|tipuri", "TYPE declară tipuri noi, din cele de bază (INTEGER, REAL, CHAR, BOOLEAN, BYTE, SET) sau construite cu ARRAY, RECORD, POINTER și PROCEDURE.¶¶TYPE Punct = RECORD x, y: INTEGER END;¶ ");
    GA("    Lista = POINTER TO Nod;");
  G("var|variabila|variabile", "VAR declară variabile: nume, două puncte, tip. Într-o listă de parametri, VAR înseamnă transmitere prin referință: procedura poate schimba variabila celui care o cheamă.¶¶VAR i, n:");
    GA(" INTEGER; nume: ARRAY 32 OF CHAR;");
  G("procedure|procedura|proceduri|functie", "PROCEDURE declară o procedură: antetul (nume, parametri, eventual tipul rezultatului), declarațiile locale, BEGIN cu instrucțiunile și, în Oberon-07, RETURN expresie o singură dată");
    GA(", la sfârșit, înainte de END Nume.¶¶PROCEDURE Max*(a, b: INTEGER): INTEGER;¶  VAR m: INTEGER;¶BEGIN¶  IF a > b THEN m := a ELSE m := b END¶  RETURN m¶END Max;");
  G("begin", "BEGIN deschide partea cu instrucțiuni a unui modul sau a unei proceduri.");
  G("end", "END închide: modulul (END Nume.), procedura (END Nume;), RECORD, IF, CASE, WHILE, FOR (și LOOP, WITH în Oberon-2). REPEAT se închide cu UNTIL, nu cu END.");
  G("return", "RETURN dă rezultatul unei funcții. În Oberon-07 apare o singură dată, la sfârșitul corpului, chiar înainte de END. În Oberon-2 poate apărea oriunde și oprește procedura pe loc.");
  G("if|then|elsif|else|daca", "IF alege între ramuri: IF condiție THEN … {ELSIF condiție THEN …} [ELSE …] END.¶¶IF x > 0 THEN semn := 1 ELSIF x < 0 THEN semn := -1 ELSE semn := 0 END");
  G("case|of", "CASE alege după valoarea unei expresii întregi sau caracter: CASE x OF 0: … | 1, 3..5: … END. Oberon-07 n-are ELSE la CASE: dacă nicio etichetă nu se potrivește, programul se opreș");
    GA("te (trap). Oberon-07 permite și CASE după tipul unui pointer, cu tipuri ca etichete. Oberon-ul vechi și Oberon-2 au CASE … ELSE.¶¶CASE ch OF `a`..`z`: litera := TRUE | `0`..`9`: ci");
    GA("fra := TRUE END");
  G("while|do", "WHILE repetă cât timp condiția e adevărată: WHILE c DO … END. Oberon-07 are și forma cu ELSIF (bucla lui Dijkstra): WHILE c1 DO s1 ELSIF c2 DO s2 END repetă până când nicio condiți");
    GA("e nu mai e adevărată.¶¶WHILE i < n DO s := s + a[i]; INC(i) END");
  G("repeat|until", "REPEAT … UNTIL condiție: corpul rulează cel puțin o dată și se repetă până când condiția devine adevărată.¶¶REPEAT Texts.Read(R, ch) UNTIL R.eot OR (ch > ` `)");
  G("for|to|by", "FOR numără: FOR i := a TO b BY pas DO … END. Pasul (BY) e o constantă, implicit 1, și poate fi negativ.¶¶FOR i := 0 TO LEN(a) - 1 DO a[i] := 0 END");
  G("loop|exit", "LOOP și EXIT vin din Oberon-ul vechi și din Oberon-2 (Wirth le-a scos din Oberon-07): LOOP … END repetă la nesfârșit, iar EXIT iese din cea mai apropiată buclă LOOP. În Oberon-07 s");
    GA("e scrie cu WHILE sau REPEAT.");
  G("with", "WITH vine din Oberon-ul vechi și din Oberon-2: WITH v: T DO … END e o gardă de tip pe o regiune — înăuntru, v e tratată ca tipul T. În Oberon-07 se folosește CASE după tip, testul ");
    GA("v IS T sau garda v(T).");
  G("array|tablou|vector", "ARRAY e tabloul: ARRAY 10 OF INTEGER; cu mai multe dimensiuni: ARRAY 3, 4 OF REAL. Indicii pornesc de la 0. Tablourile deschise (ARRAY OF CHAR) sunt voie în Oberon-07 doar ca tip d");
    GA("e parametru; LEN(a) dă lungimea.");
  G("record|inregistrare", "RECORD grupează câmpuri cu nume: RECORD x, y: INTEGER END. Se poate extinde: RECORD (Baza) z: INTEGER END moștenește câmpurile lui Baza (extensie de tip), iar o variabilă de tipul ");
    GA("extins poate fi folosită unde se cere Baza.");
  G("pointer|nil|referinta", "POINTER TO T e o referință la o variabilă T creată dinamic cu NEW(p). În Oberon-07, T trebuie să fie RECORD (în Oberon-2 poate fi și ARRAY). NIL e pointerul care nu arată nimic. Me");
    GA("moria se eliberează singură (colector de gunoi). p^ e variabila arătată; p.camp e prescurtare pentru p^.camp.");
  G("is", "IS testează tipul: p IS T e adevărat dacă variabila arătată de p e de tipul T sau de o extensie a lui.");
  G("in", "IN testează apartenența la o mulțime: IF i IN s THEN … END.");
  G("div|mod", "DIV e împărțirea întreagă, MOD restul: 7 DIV 2 = 3, 7 MOD 2 = 1. Restul e mereu între 0 și împărțitor (pentru împărțitor pozitiv), deci -7 DIV 2 = -4 și -7 MOD 2 = 1.");
  G("or|&|~|si|sau|not", "Operatorii logici: OR (sau), & (și), ~ (nu). Se evaluează pe scurt: în a & b, b nu mai e calculat dacă a e FALSE; în a OR b, b nu mai e calculat dacă a e TRUE.");
  G(":=|atribuire", "„:=” e atribuirea: x := expresie. „=” e comparație, nu atribuire.");
  G("#|diferit", "„#” înseamnă diferit (≠): IF x # 0 THEN … END.");
  G("export|*|exporta", "Steluța după nume îl exportă: alte module îl pot folosi ca Modul.Nume. Oberon-2 are și „-”: export doar pentru citire.");
  G("boolean|true|false", "BOOLEAN are două valori: TRUE și FALSE.");
  G("char|caracter|ord|chr", "CHAR e un caracter: `A` sau, după cod, 41X (cifre hexa urmate de X). ORD(ch) dă codul, CHR(n) caracterul. Sfârșitul unui șir e 0X.");
  G("integer|intreg", "INTEGER e numărul întreg. În Project Oberon (procesorul RISC5) are 32 de biți. Oberon-2 mai are SHORTINT și LONGINT.");
  G("real", "REAL e numărul cu virgulă: 3.14, 1.0E6. FLT(i) face din întreg real, FLOOR(x) face din real întreg (în jos). Oberon-2 mai are LONGREAL.");
  G("byte", "BYTE e un întreg între 0 și 255 (Oberon-07). Se poate atribui unui INTEGER și invers (dacă încape).");
  G("set|multime", "SET e o mulțime de numere mici (0..31 pe 32 de biți): {0, 2..5}. + reuniune, * intersecție, - diferență, / diferență simetrică; INCL(s, i) și EXCL(s, i) adaugă și scot un element.");
  G("longint|shortint|longreal", "LONGINT, SHORTINT și LONGREAL sunt tipuri din Oberon-2. Oberon-07 a rămas doar cu INTEGER, REAL și BYTE.");
  G("string|siruri|sir", "Un șir e un tablou de CHAR încheiat cu 0X. Constanta se scrie între ghilimele: `text`. În Oberon-07 se poate atribui direct: nume := `Eula` (dacă încape). În Oberon-2 se folosește ");
    GA("COPY(`text`, nume).");
  G("abs", "ABS(x): valoarea absolută, pentru INTEGER sau REAL.");
  G("odd", "ODD(n): TRUE dacă n e impar.");
  G("len", "LEN(a): lungimea unui tablou; la tablouri cu mai multe dimensiuni, LEN(a, d) dă dimensiunea d (Oberon-2).");
  G("lsl|asr|ror", "Deplasări pe biți (Oberon-07): LSL(x, n) la stânga, ASR(x, n) la dreapta cu semn, ROR(x, n) rotire la dreapta.");
  G("floor|flt|entier", "FLOOR(x) face din REAL un INTEGER rotunjind în jos, FLT(i) face din INTEGER un REAL (Oberon-07). În Oberon-2, ENTIER(x) face ce face FLOOR.");
  G("inc|dec", "INC(v) mărește v cu 1, INC(v, n) cu n; DEC le micșorează.");
  G("incl|excl", "INCL(s, x) pune x în mulțimea s, EXCL(s, x) îl scoate.");
  G("new", "NEW(p) creează o variabilă nouă de tipul arătat de pointerul p și pune adresa ei în p.");
  G("assert", "ASSERT(condiție) oprește programul (trap) dacă condiția e falsă. Bun pentru a prinde greșelile devreme.");
  G("pack|unpk", "PACK(x, n) și UNPK(x, n) lucrează cu exponentul unui REAL (Oberon-07, pentru biblioteca de matematică).");
  G("min|max|cap|short|long|size|copy|halt|ash", "MIN, MAX, CAP, SHORT, LONG, SIZE, COPY, HALT și ASH sunt proceduri predefinite din Oberon-2 (Oberon-07 le-a scos sau le-a înlocuit: ASH cu LSL/ASR, COPY cu atribuirea).");
  G("system", "SYSTEM e un pseudo-modul pentru lucrul la nivel jos: SYSTEM.ADR, SYSTEM.GET, SYSTEM.PUT, SYSTEM.VAL, SYSTEM.SIZE, SYSTEM.BIT, SYSTEM.COPY. Un modul care îl importă nu mai e portabi");
    GA("l.");
  G("oberon", "Oberon e un limbaj și un sistem de operare făcute de Niklaus Wirth și Jürg Gutknecht la ETH Zürich, între 1985 și 1987. Vine după Pascal și Modula-2. Oberon-2 (1991, Mössenböck și ");
    GA("Wirth) a adăugat proceduri legate de tip, export doar pentru citire și FOR. Oberon-07 (2007, revizuit până în 2016) e versiunea simplificată din Project Oberon.");
  G("oberon-07|oberon07", "Oberon-07 e revizia lui Wirth din 2007 (ultima formă în 2016): a scos LOOP, EXIT, WITH, a lăsat RETURN doar la sfârșit, a adăugat WHILE … ELSIF și tipul BYTE. E limbajul din Projec");
    GA("t Oberon și din compilatorul OBNC.");
  G("oberon-2|oberon2", "Oberon-2 (1991, Hanspeter Mössenböck și Niklaus Wirth) a adăugat la Oberon proceduri legate de tip (metode), export doar pentru citire („-”), pointeri la tablouri deschise, FOR și ");
    GA("WITH cu mai multe ramuri. Compilatorul voc de pe telefonul tău e Oberon-2.");
  G("wirth|niklaus", "Niklaus Wirth (1934–2024), profesor la ETH Zürich, a creat Pascal, Modula-2 și Oberon. A primit premiul Turing în 1984.");
  G("gutknecht", "Jürg Gutknecht, coautor cu Wirth al sistemului Oberon și al cărții Project Oberon.");
  G("project-oberon|projectoberon", "Project Oberon e cartea lui Wirth și Gutknecht (ediția revizuită 2013): un sistem întreg, de la procesorul RISC5 pe FPGA la compilator și sistemul de operare, descris complet. Surs");
    GA("ele lui (licență liberă) sunt în memoria mea.");
  G("risc5|risc", "RISC5 e procesorul simplu proiectat de Wirth pentru Project Oberon; compilatorul ORP/ORG generează cod pentru el. Oberon Lab din Cub rulează un emulator RISC5.");
  G("voc|vishap", "voc (Vishap Oberon Compiler) e un compilator Oberon-2 care traduce în C. Pe telefonul tău stă în ~/voc; bibliotecile lui sunt în memoria mea.");
  G("obnc", "OBNC e compilatorul Oberon-07 al lui Karl Landström; traduce în C.");
  G("ors|orp|org|orb", "ORS, ORB, ORG și ORP sunt compilatorul din Project Oberon: ORS e scanerul, ORB tabela de simboluri, ORG generatorul de cod pentru RISC5, ORP parserul care le leagă. Un compilator O");
    GA("beron întreg în patru module.");
  G("legata|metoda|metode|type-bound|receptor", "O procedură legată de tip (o metodă) e din Oberon-2: PROCEDURE (p: Punct) Muta*(dx: INTEGER); și se cheamă p.Muta(1). Receptorul (aici p, de tipul Punct) e un RECORD sau un pointer");
    GA(" la RECORD, iar extensiile tipului o pot redefini. Oberon-07 nu le are: acolo se pun proceduri în câmpurile record-ului (handler-e), cum face sistemul Oberon.");
  G("garda|guard", "Garda de tip v(T) spune compilatorului să trateze v ca fiind de tipul extins T; dacă la rulare nu e, programul se oprește.");
  G("extensie", "Extensia de tip: TYPE B = RECORD (A) … END. B are toate câmpurile lui A plus ale lui; un B poate sta unde se cere un A.");
  G("comanda|command", "În sistemul Oberon, orice procedură exportată fără parametri e o comandă: scrii Modul.Procedura într-un text și dai clic pe ea.");
  G("colector|gunoi|garbage", "Oberon are colector de gunoi: memoria creată cu NEW se eliberează singură când nu mai arată nimic spre ea.");
  G("eula", "Eu sunt Eula Oberon. Știu doar Oberon: sintaxa din raportul lui Wirth și codul pe care l-am mâncat.");
  E("fisier", "file files");
  E("deschid", "open old");
  E("deschide", "open old");
  E("inchid", "close");
  E("inchide", "close");
  E("scri", "write");
  E("scrie", "write");
  E("citi", "read");
  E("cite", "read");
  E("sir", "string");
  E("siruri", "string");
  E("caracter", "char");
  E("numar", "int number");
  E("numer", "int number");
  E("intreg", "int integer");
  E("lungime", "length len");
  E("text", "text texts");
  E("ecran", "display screen");
  E("afis", "display write show");
  E("fereastr", "viewer window");
  E("tast", "key keyboard");
  E("mouse", "mouse");
  E("soarece", "mouse");
  E("cursor", "cursor");
  E("memori", "memory heap");
  E("aloc", "new alloc");
  E("list", "list");
  E("arbor", "tree");
  E("caut", "search find");
  E("gase", "find search");
  E("sort", "sort");
  E("ordon", "sort order");
  E("compar", "compare");
  E("copi", "copy");
  E("sterg", "delete remove");
  E("insera", "insert");
  E("adaug", "append insert add");
  E("timp", "time clock");
  E("ceas", "clock time");
  E("ora", "time clock");
  E("data", "date");
  E("aleator", "random");
  E("intampl", "random");
  E("radacin", "sqrt");
  E("sinus", "sin");
  E("cosinus", "cos");
  E("putere", "power exp");
  E("rotunj", "round floor entier");
  E("conver", "convert");
  E("modul", "module");
  E("procedur", "procedure");
  E("tip", "type");
  E("variabil", "var");
  E("constant", "const");
  E("eroare", "error trap");
  E("greseal", "error");
  E("iesire", "out output");
  E("intrare", "input");
  E("linie", "line ln");
  E("rand", "line ln");
  E("cuvant", "word name");
  E("nume", "name");
  E("culoare", "color");
  E("linii", "line");
  E("desen", "draw graph");
  E("deseneaz", "draw");
  E("punct", "dot point");
  E("dreptungh", "rect rectangle");
  E("cerc", "circle");
  E("font", "font");
  E("litera", "char letter");
  E("compil", "compile compiler");
  E("scaner", "scanner scan");
  E("simbol", "symbol sym");
  E("cod", "code");
  E("retea", "net network");
  E("trimit", "send");
  E("primesc", "receive");
  E("primi", "receive");
  E("port", "port");
  E("disc", "disk");
  E("sector", "sector");
  E("director", "directory dir");
  E("cale", "path");
  E("marime", "size");
  E("dimensiun", "size");
  E("pozitie", "pos position");
  E("lung", "length");
  E("gol", "empty");
  E("plin", "full");
  E("inceput", "begin start");
  E("sfarsit", "end");
  E("inapoi", "back");
  E("urmator", "next");
  E("precedent", "prev");
  E("semnal", "signal");
  E("proces", "process task");
  E("sarcin", "task");
  E("comand", "command");
  E("parametr", "param par");
  E("hexa", "hex");
  E("real", "real")
END Raport.
