MODULE Shell;  (* shell-ul Eulei: citeste un rand si cheama Modul.Comanda, cu restul randului ca parametri (Param) *)
  IMPORT In, Out, Strings, Param, Dosar, Nucleu;

  CONST N = 2048; MaxA = 40;

  VAR scurt, lung: ARRAY MaxA OF ARRAY 32 OF CHAR;   (* numele scurte: ls -> Fisiere.Lista *)
    na: INTEGER;

  PROCEDURE A(s, l: ARRAY OF CHAR);
  BEGIN
    IF na < MaxA THEN Strings.Copy(s, scurt[na]); Strings.Copy(l, lung[na]); INC(na) END
  END A;

  PROCEDURE Ajutor*;
  BEGIN
    Out.String("Eula: un sistem Oberon. Orice procedura exportata fara parametri e o comanda:"); Out.Ln;
    Out.String("  Modul.Comanda parametri      de ex.  Fisiere.Lista  sau  Vopsea.Litri 4 3"); Out.Ln; Out.Ln;
    Out.String("  ruleaza X.Mod  (sau doar X.Mod)   compileaza si porneste programul"); Out.Ln;
    Out.String("  compileaza X.Mod   modulele intra in biblioteca; comenzile lor raman"); Out.Ln;
    Out.String("  module             ce module ai (ale sistemului si ale tale)"); Out.Ln;
    Out.String("  comenzi [Modul]    ce comenzi are un modul"); Out.Ln;
    Out.String("  uita Modul         scoate un modul al tau din biblioteca"); Out.Ln;
    Out.String("  edit X.Mod         editorul (Salveaza / Ruleaza)"); Out.Ln;
    Out.String("  ls  cd  pwd  cat  cp  mv  rm  mkdir     fisiere"); Out.Ln;
    Out.String("  descarca URL [fisier]   de pe internet"); Out.Ln;
    Out.String("  apk X.Mod [Nume]   face o aplicatie Android din modul (vezi BusolaApp.Mod, Nivela.Mod, Labirint.Mod)"); Out.Ln;
    Out.String("  apk X.Mod Nume eula   la fel, cu toata Eula Oberon inauntru (ex: apk CubicumOS.Mod Cubicum eula)"); Out.Ln;
    Out.String("                     iconita o deseneaza Eula; pui X.png langa sursa ca s-o alegi tu"); Out.Ln;
    Out.String("  html               face aplicatii din toate paginile din Download/html (+ zip pentru itch.io)"); Out.Ln;
    Out.String("  html X.html [Nume] una singura, si o da la instalat"); Out.Ln;
    Out.String("  acces              da-i Eulei voie la fisierele telefonului (Download)"); Out.Ln;
    Out.String("  sh [comanda]       shell-ul Android (exit = inapoi)"); Out.Ln;
    Out.String("  inferno [comanda]  sh-ul lui Inferno, aici in terminal (exit = inapoi)"); Out.Ln;
    Out.String("  charon [adresa]    browserul lui Inferno, pe ecran (https, cu TLS 1.3)"); Out.Ln;
    Out.String("  wm                 biroul lui Inferno, pe ecran (meniul din coltul de jos)"); Out.Ln;
    Out.String("  eula               inapoi la conversatia cu Eula"); Out.Ln;
    Out.String("  curata             sterge ecranul"); Out.Ln;
    Out.String("  Ctrl+C             opreste comanda care ruleaza"); Out.Ln; Out.Ln;
    Out.String("Exemple in casa ta: Salut.Mod, Vopsea.Mod (o comanda), Busola.Mod (senzorul), BusolaApp.Mod (aplicatie: apk BusolaApp.Mod), Nivela.Mod (apk Nivela.Mod Nivela), Labirint.Mod (apk Labirint.Mod Labirint), CubDans.Mod (apk CubDans.Mod CubDans),"); Out.Ln;
    Out.String("Eula7.Mod (o aplicatie care vorbeste, Eula 7 scrisa in Oberon: apk Eula7.Mod Eula7)"); Out.Ln;
    Out.String("Sursele sistemului (Shell, Fisiere, Net, Module) sunt in ~/sistem: modele pentru comenzile tale."); Out.Ln
  END Ajutor;

  PROCEDURE Prompt;
    VAR d, a, u: ARRAY N OF CHAR; i: INTEGER;
  BEGIN
    Dosar.Curent(d); Dosar.Acasa(a);
    Out.String("eula:");
    IF d = a THEN Out.String("~")
    ELSIF Strings.Length(d) <= 1 THEN Out.String(d)
    ELSE
      i := Strings.Length(d) - 1;
      WHILE (i > 0) & (d[i] # "/") DO DEC(i) END;
      Strings.Extract(d, i + 1, N, u); Out.String(u)
    END;
    Out.String("> ")
  END Prompt;

  (* primul cuvant -> cmd, restul -> rest *)
  PROCEDURE Imparte(VAR r, cmd, rest: ARRAY OF CHAR);
    VAR i, k: INTEGER;
  BEGIN
    i := 0;
    WHILE (r[i] # 0X) & (r[i] <= " ") DO INC(i) END;
    k := 0;
    WHILE (r[i] > " ") & (k < LEN(cmd) - 1) DO cmd[k] := r[i]; INC(k); INC(i) END;
    cmd[k] := 0X;
    WHILE (r[i] # 0X) & (r[i] <= " ") DO INC(i) END;
    k := 0;
    WHILE (r[i] # 0X) & (k < LEN(rest) - 1) DO rest[k] := r[i]; INC(k); INC(i) END;
    rest[k] := 0X
  END Imparte;

  PROCEDURE SeTermina(s, cu: ARRAY OF CHAR): BOOLEAN;
    VAR a, b: INTEGER; ok: BOOLEAN;
  BEGIN
    a := Strings.Length(s); b := Strings.Length(cu); ok := a > b;
    WHILE ok & (b > 0) DO DEC(a); DEC(b); ok := s[a] = cu[b] END
    RETURN ok
  END SeTermina;

  PROCEDURE Cheama(VAR modul, comanda, rest: ARRAY OF CHAR);
    VAR e: ARRAY 256 OF CHAR; c: ARRAY 64 OF CHAR; r, k, j: INTEGER;
  BEGIN
    Param.Seteaza(rest);
    r := Nucleu.Cheama(modul, comanda);
    IF r = 1 THEN Nucleu.Eroare(e); Out.String(e); Out.String(" (scrie module)"); Out.Ln
    ELSIF r = 2 THEN
      Nucleu.Eroare(e); Out.String(e); Out.Ln;
      k := Nucleu.Comenzi(modul);
      IF k > 0 THEN
        Out.String("are:");
        FOR j := 0 TO k - 1 DO Nucleu.Comanda(j, c); Out.String(" "); Out.String(c) END;
        Out.Ln
      END
    END
  END Cheama;

  PROCEDURE Executa(VAR rand: ARRAY OF CHAR);
    VAR cmd, rest, tot: ARRAY N OF CHAR; modul, comanda: ARRAY 64 OF CHAR; i, k: INTEGER;
  BEGIN
    Imparte(rand, cmd, rest);
    IF cmd = "" THEN (* nimic *)
    ELSIF (cmd = "ajutor") OR (cmd = "?") OR (cmd = "help") THEN Ajutor
    ELSIF (cmd = "iesire") OR (cmd = "exit") THEN Nucleu.Opreste(0)
    ELSIF cmd = "eula" THEN Nucleu.Terminal("eula")
    ELSIF cmd = "sh" THEN k := Nucleu.Sh(rest)
    ELSIF cmd = "inferno" THEN k := Nucleu.Inferno(rest)
    ELSIF cmd = "charon" THEN
      tot := "inferno;charon "; Strings.Append(rest, tot); Nucleu.Terminal(tot)
    ELSIF cmd = "wm" THEN tot := "inferno;"; Nucleu.Terminal(tot)
    ELSIF (cmd = "curata") OR (cmd = "clear") THEN Out.Char(1BX); Out.String("[H"); Out.Char(1BX); Out.String("[2J")
    ELSIF SeTermina(cmd, ".Mod") THEN
      Strings.Copy(cmd, tot); Strings.Append(" ", tot); Strings.Append(rest, tot);
      modul := "Module"; comanda := "Ruleaza"; Cheama(modul, comanda, tot)
    ELSE
      i := 0; WHILE (i < na) & (scurt[i] # cmd) DO INC(i) END;
      IF i < na THEN Strings.Copy(lung[i], cmd) END;
      k := Strings.Pos(".", cmd, 0);
      IF (k <= 0) OR (cmd[k + 1] = 0X) THEN
        Out.String("nu stiu comanda "); Out.String(cmd); Out.String(" (scrie ajutor)"); Out.Ln
      ELSE
        Strings.Extract(cmd, 0, k, modul);
        Strings.Extract(cmd, k + 1, N, comanda);
        Cheama(modul, comanda, rest)
      END
    END
  END Executa;

  PROCEDURE Porneste*;   (* bucla shell-ului: o porneste sistemul *)
    VAR rand: ARRAY N OF CHAR; gata: BOOLEAN;
  BEGIN
    Out.String("Eula, sistem Oberon. Scrie ajutor."); Out.Ln;
    gata := FALSE;
    WHILE ~gata DO
      Prompt;
      In.String(rand);
      IF ~In.Done THEN gata := TRUE ELSE Executa(rand) END
    END
  END Porneste;

BEGIN
  na := 0;
  A("ls", "Fisiere.Lista"); A("dir", "Fisiere.Lista"); A("cd", "Fisiere.Schimba"); A("pwd", "Fisiere.Unde");
  A("cat", "Fisiere.Arata"); A("cp", "Fisiere.Copiaza"); A("mv", "Fisiere.Muta"); A("rm", "Fisiere.Sterge");
  A("mkdir", "Fisiere.Creeaza"); A("edit", "Fisiere.Edit");
  A("descarca", "Net.Descarca"); A("wget", "Net.Descarca"); A("curl", "Net.Descarca");
  A("compileaza", "Module.Compileaza"); A("oc", "Module.Compileaza");
  A("ruleaza", "Module.Ruleaza"); A("ob", "Module.Ruleaza");
  A("module", "Module.Lista"); A("comenzi", "Module.Comenzi"); A("uita", "Module.Uita");
  A("apk", "Aplicatie.Fa"); A("instaleaza", "Aplicatie.Instaleaza");
  A("html", "Aplicatie.Html"); A("acces", "Aplicatie.Acces")
END Shell.
