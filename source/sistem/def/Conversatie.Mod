(* Conversatie: aplicatiile Oberon facute cu apk X.Mod care vorbesc (ca Eula 7), nu deseneaza. Merge doar intr-o aplicatie.
   Modulul tau exporta Apasa* (chemata cand apesi un buton sau Enter; Apasat() spune care) si poate exporta
   Porneste* (o data, la inceput), Primeste* (dupa ce ai ales un fisier cu AlegeFisier), Pauza* (cand aplicatia trece in spate),
   Tic* (cu Ceas: o treaba lunga, cate un pas, cat poti vorbi intre timp).
   Toate se cheama pe rand, pe un singur fir; cat lucreaza una, butoanele nu mai cheama nimic.
   Fisierele din dosarul X/ de langa X.Mod intra in aplicatie: Resursa("nume", cale) ti-l da ca fisier.
   Implementat in Java (aplicatie/java/Conversatie.java). *)
DEFINITION Conversatie;
  PROCEDURE Titlu(s: ARRAY OF CHAR);                       (* titlul mare, sus *)
  PROCEDURE Stare(s: ARRAY OF CHAR);                       (* randul mic de langa titlu *)
  PROCEDURE Spune(culoare: INTEGER; cine, ce: ARRAY OF CHAR);   (* un paragraf nou: cine ingrosat in culoare, apoi ce;
                                                              cine = "" -> tot paragraful in culoare *)
  PROCEDURE Buton(nr: INTEGER; eticheta: ARRAY OF CHAR; fond, scris: INTEGER);
                                                           (* nr 1..8 = randul de butoane mici, 11..18 = randul mare;
                                                              eticheta "" = scoate butonul *)
  PROCEDURE Apasat(): INTEGER;                             (* butonul care a chemat Apasa; 0 = Enter din tastatura *)
  PROCEDURE Intrare(VAR s: ARRAY OF CHAR);                 (* ce e scris in casuta; casuta se goleste *)
  PROCEDURE AlegeFisier;                                   (* alegatorul de fisiere al telefonului; apoi Primeste *)
  PROCEDURE Ales(VAR cale, nume: ARRAY OF CHAR);           (* copia fisierului ales (in dosarul aplicatiei) si numele lui;
                                                              cale = "" daca n-ai ales nimic *)
  PROCEDURE Dosar(VAR s: ARRAY OF CHAR);                   (* dosarul aplicatiei: aici tii fisierele tale *)
  PROCEDURE Resursa(nume: ARRAY OF CHAR; VAR cale: ARRAY OF CHAR): BOOLEAN;   (* un fisier din dosarul X/ *)
  PROCEDURE Adauga(cale: ARRAY OF CHAR; b: ARRAY OF BYTE; n: INTEGER): BOOLEAN;   (* n octeti la capatul fisierului *)
  PROCEDURE Acum(VAR s: ARRAY OF CHAR);                    (* milisecundele de la 1970, ca text *)
  PROCEDURE Ms(): INTEGER;                                 (* milisecunde de cand a pornit aplicatia *)
  PROCEDURE Tine(cheie, valoare: ARRAY OF CHAR);           (* o setare mica, tinuta minte intre porniri *)
  PROCEDURE Setare(cheie: ARRAY OF CHAR; VAR valoare: ARRAY OF CHAR);   (* "" daca n-a fost tinuta *)
  (* v22: reteaua si ceasul *)
  PROCEDURE Aduce(adresa, cale: ARRAY OF CHAR; VAR finala, tip: ARRAY OF CHAR): INTEGER;
                                                           (* aduce adresa prin Android (https, redirectionari) in fisierul
                                                              cale, ca text UTF-8; intoarce codul HTTP (200 = bine), -1 fara retea;
                                                              finala = adresa unde a ajuns, tip = Content-Type *)
  PROCEDURE Descarcari(VAR d: ARRAY OF CHAR): BOOLEAN;     (* dosarul Download, daca am voie; altfel cere voie si da FALSE *)
  PROCEDURE Ceas(ms: INTEGER);                             (* Tic* la fiecare ms (cand nu lucreaza altceva); 0 = oprit *)
END Conversatie.
