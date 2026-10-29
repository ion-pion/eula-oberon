(* Senzor: senzorii telefonului: busola, gravitatia (pentru nivela) si miscarea pe verticala. Ecranul Eulei citeste busola si ii da sistemului
   valoarea; gravitatia merge doar in aplicatii (apk X.Mod), nu in terminal.
   Implementat in Java (sistem/java/Senzor.java + Terminal.java; in aplicatii: aplicatie/java/Senzor.java). *)
DEFINITION Senzor;
  PROCEDURE Porneste(): BOOLEAN;   (* porneste busola; FALSE daca telefonul n-are senzor magnetic *)
  PROCEDURE Azimut(): INTEGER;     (* 0..359 grade, 0 = nord, 90 = est; -1 daca inca nu stiu *)
  PROCEDURE Opreste;
  PROCEDURE PornesteGravitatia(): BOOLEAN;   (* incotro trage pamantul; FALSE daca nu se poate *)
  PROCEDURE GX(): INTEGER;   (* miimi de g de-a lungul ecranului, spre dreapta; telefonul culcat pe masa: GX = GY = 0, GZ = 1000 *)
  PROCEDURE GY(): INTEGER;   (* miimi de g spre susul ecranului; telefonul in picioare: GY = 1000 *)
  PROCEDURE GZ(): INTEGER;   (* miimi de g iesind din ecran, spre tine *)
  PROCEDURE PornesteMiscarea(): BOOLEAN;   (* acceleratia fara gravitatie: cand misti telefonul *)
  PROCEDURE Sus(): INTEGER;   (* miimi de g pe verticala adevarata (spre cer), oricum ai tine telefonul:
                                 il ridici brusc = intai pozitiv, apoi negativ cand il opresti *)
  PROCEDURE LX(): INTEGER;   (* acceleratia fara gravitatie (dupa PornesteMiscarea), miimi de g, pe axele ecranului: *)
  PROCEDURE LY(): INTEGER;   (*   LX spre dreapta ecranului, LY spre susul lui, LZ iesind din ecran spre tine;  *)
  PROCEDURE LZ(): INTEGER;   (*   misti telefonul brusc la dreapta = intai LX pozitiv, apoi negativ cand il opresti *)
END Senzor.
