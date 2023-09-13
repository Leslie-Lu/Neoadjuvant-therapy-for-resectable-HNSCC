
/* Version 1.3 create.cause.specific.and.other.death.classification.sas               */
/* This SAS program is provided to calculate 2 fields which are described at          */
/*  https://seer.cancer.gov/causespecific/                                            */
/*  In addition to descriptions of the fields, you can find other documentation       */
/*  and contact information on the web page.                                          */

/* Fields are only calculated for sequence 0-59                                       */
/* Logic is different for sequence # 0 vs 1-59 - e.g. any cancer death (regardless of */
/* site) is considered dead due to the cancer of dx for sequence # 0 - assumes        */
/* misclassification - e.g. death coded as site of mets                               */
/* All other sequence numbers have resultant value of 9, death after study cut-off    */
/* is coded as alive (0 - non-event in both), unknown COD (7777 or 7797 or missing)   */
/* is coded as 8 in both. Otherwise 0 is non-event (e.g. not due to cancer for        */
/* cause-specific) 1 for event (e.g. due to cancer for cause-specific)                */

/* Version 1.1 (9/16/2019)                                                            */
/*   - Changed the default for the study cut-off to 2017                              */
/*   - Changed input and output columns to NAACCR record layout version 18            */

/* Verison 1.2 (1/15/2020)                                                            */
/*   - Fixed a problem for Anus, Anal Canal and Anorectum                             */
/*   - Added death from cancers of small intestine, CR, and anus, anal canal, and     */
/*     anorectum for sequence # 1 tumors as cause-specific deaths                     */

/* Verison 1.3 (4/6/2020)                                                             */
/*   - Updated to calculate for sequence #s 0-59                                      */
/*   - Prior versions only calculated for sequence #s 0 and 1                         */

options missing=' ';

/* Assumptions:                                                                       */
/*   study cutoff will be 12/31/xxxx                                                  */

%LET STUDYCUTOFFYEAR = 2017; /* if death after 12/31/XXXX then fields are set to alive */
%LET ExcludeICDCodes = 0;    /* setting ExcludeICDCodes to 1 will remove from the output */

filename in  "input.txt";
filename out "myoutputfile.txt";    /* if using in SEER*Pep, change extension to .txd  */

proc format;
  value siterecf
    20010="Lip"
    20020="Tongue"
    20030="Salivary Gland"
    20040="Floor of Mouth"
    20050="Gum and Other Mouth"
    20060="Nasopharynx"
    20070="Tonsil"
    20080="Oropharynx"
    20090="Hypopharynx"
    20100="Other Oral Cavity and Pharynx"
    21010="Esophagus"
    21020="Stomach"
    21030="Small Intestine"
    21041="Cecum"
    21042="Appendix"
    21043="Ascending Colon"
    21044="Hepatic Flexure"
    21045="Transverse Colon"
    21046="Splenic Flexure"
    21047="Descending Colon"
    21048="Sigmoid Colon"
    21049="Large Intestine, NOS"
    21051="Rectosigmoid Junction"
    21052="Rectum"
    21060="Anus, Anal Canal and Anorectum"
    21071="Liver"
    21072="Intrahepatic Bile Duct"
    21080="Gallbladder"
    21090="Other Biliary"
    21100="Pancreas"
    21110="Retroperitoneum"
    21120="Peritoneum, Omentum and Mesentery"
    21130="Other Digestive Organs"
    22010="Nose, Nasal Cavity and Middle Ear"
    22020="Larynx"
    22030="Lung and Bronchus"
    22050="Pleura"
    22060="Trachea, Mediastinum and Other Respiratory Organs"
    23000="Bones and Joints"
    24000="Soft Tissue including Heart"
    25010="Melanoma of the Skin"
    25020="Other Non-Epithelial Skin"
    26000="Breast"
    27010="Cervix Uteri"
    27020="Corpus Uteri"
    27030="Uterus, NOS"
    27040="Ovary"
    27050="Vagina"
    27060="Vulva"
    27070="Other Female Genital Organs"
    28010="Prostate"
    28020="Testis"
    28030="Penis"
    28040="Other Male Genital Organs"
    29010="Urinary Bladder"
    29020="Kidney and Renal Pelvis"
    29030="Ureter"
    29040="Other Urinary Organs"
    30000="Eye and Orbit"
    31010="Brain"
    31040="Cranial Nerves Other Nervous System"
    32010="Thyroid"
    32020="Other Endocrine including Thymus"
    33011="Hodgkin - Nodal"
    33012="Hodgkin - Extranodal"
    33041="NHL - Nodal"
    33042="NHL - Extranodal"
    34000="Myeloma"
    35011="Acute Lymphocytic Leukemia"
    35012="Chronic Lymphocytic Leukemia"
    35013="Other Lymphocytic Leukemia"
    35021="Acute Myeloid Leukemia"
    35031="Acute Monocytic Leukemia"
    35022="Chronic Myeloid Leukemia"
    35023="Other Myeloid/Monocytic Leukemia"
    35041="Other Acute Leukemia"
    35043="Aleukemic, Subleukemic and NOS"
    36010="Mesothelioma"
    36020="Kaposi Sarcoma"
    37000="Miscellaneous"
    ;
  value codrelf
    0="Alive or dead of other causes"
    1="Dead (attributable to this cancer dx)"
    8="Dead (missing/unknown COD)"
    9="N/A not first tumor"
    ;
  value codverf
    0='Patient is alive at last follow-up'
    8='Eighth ICD revision'
    9='Ninth ICD revision'
    1='Tenth ICD revision'
    ;

/* read in data and create site recode which is required */
data all;
  infile in lrecl=4048;
  format sitewho siterecf. codver codverf.;
  input @   1 buffer        $char4048.
        @ 542 seqnum        2.            /* NAACCRItemNumber 380   */
        @ 555 prim_site     3.            /* NAACCRItemNumber 400   */
        @ 564 hist_o_3      4.            /* NAACCRItemNumber 522   */
        @2775 year_dth      4.            /* NAACCRItemNumber 1750  */
        @2940 cod89_3dig    3.            /* NAACCRItemNumber 1910  */
        @2940 cod89_4dig    4.            /* NAACCRItemNumber 1910  */
        @2940 cod_full      $char4.       /* NAACCRItemNumber 1910  */
        @2940 cod10char     $char1.       /* NAACCRItemNumber 1910  */
        @2941 cod10_3dig    3.            /* NAACCRItemNumber 1910  */
        @2941 cod10_2dig    2.            /* NAACCRItemNumber 1910  */
        @2946 codver        1.            /* NAACCRItemNumber 1920  */
        ;
  if year_dth > &STUDYCUTOFFYEAR then codver = 0; /* set to alive if death after study cut-off */
  sitewho = 99999;
  if (9050 <= hist_o_3 <= 9055) then sitewho = 36010; /* mesothelioma */
  else if (hist_o_3 = 9140) then sitewho = 36020; /* Kaposi sarcoma */
  else if (hist_o_3 >= 9590) then do;
    if (9650 <= hist_o_3 <= 9655 or 9661 <= hist_o_3 <= 9665 or hist_o_3 in (9659,9667)) then do;
      if (prim_site in (24,98,99,111,142,379,422) or 770 <= prim_site <= 779) then sitewho = 33011; /* Hodgkin - Nodal */
      else sitewho = 33012; /* Hodgkin - Extranodal  */
      end;
    else if (hist_o_3 in (9590,9591,9596,9597,9670,9671,9673,9675,9678,9679,9680,9684,9687,9688,9689,9690,9691,9695,9698,9699,9700,9701,9702,9705,9708,9709,9712,9714,9716,9717,9718,9719,
             9724,9725,9726,9727,9728,9729,9735,9737,9738,9811,9812,9813,9814,9815,9816,9817,9818,9823,9827,9837)) then do;
      if (prim_site in (24,98,99,111,142,379,422) or 770 <= prim_site <= 779) then sitewho = 33041; /* NHL - Nodal */
      else if (prim_site in (420,421,424)) then do;
        if (hist_o_3 = 9823) then sitewho = 35012;  /* Chronic Lymphocytic Leukemia */
        else if (hist_o_3 = 9827) then sitewho = 35043; /* Aleukemic, subleukemic and NOS */
        else if (hist_o_3 = 9837) or (9811 <= hist_o_3 <= 9818) then sitewho = 35011; /* Acute lymphocytic leuk */
        else sitewho = 33042; /* NHL - Extranodal  */
        end;
      else sitewho = 33042; /* NHL - Extranodal  */
      end;
    else if (hist_o_3 in (9731,9732,9734)) then sitewho = 34000; /* Myeloma */
    else if (hist_o_3 in (9826,9835,9836)) then sitewho = 35011; /* Acute Lymphocytic Leukemia */
    else if (hist_o_3 in (9820,9832,9833,9834,9940)) then sitewho = 35013; /* Other Lymphocytic Leukemia */
    else if (hist_o_3 in (9840,9861,9865,9866,9867,9869,9871,9872,9873,9874,9895,9896,9897,9898,9910,9911,9920)) then sitewho = 35021; /* Acute Myeloid Leukemia */
    else if (hist_o_3 in (9863,9875,9876,9945,9946)) then sitewho = 35022; /* Chronic Myeloid Leukemia */
    else if (hist_o_3 in (9860,9930)) then sitewho = 35023; /* Other Myeloid/Monocytic Leukemia */
    else if (hist_o_3 in (9891)) then sitewho = 35031; /* Acute Monocytic Leukemia */
    else if (hist_o_3 in (9801,9805,9806,9807,9808,9809,9931)) then sitewho = 35041; /* Other Acute Leukemia */
    else if (hist_o_3 in (9733,9742,9800,9831,9870,9948,9963,9964)) then sitewho = 35043; /* Aleukemic, subleukemic and NOS */
    else if (hist_o_3 in (9740,9741) or (9750 <= hist_o_3 <= 9769) or (9950 <= hist_o_3 <= 9962) or (9965 <= hist_o_3 <= 9992)) then sitewho = 37000; /* Miscellaneous */
    end;
  else do; /* hist < 9590 - not KS or Meso */
    if 0 <= prim_site <= 9 then sitewho = 20010;
    else if 20 <= prim_site <= 29 or prim_site = 19 then sitewho = 20020;
    else if 80 <= prim_site <= 89 or prim_site = 79 then sitewho = 20030;
    else if 40 <= prim_site <= 49 then sitewho = 20040;
    else if 30 <= prim_site <= 39 or 50 <= prim_site <= 59 or 60 <= prim_site <= 69 then sitewho = 20050;
    else if 110 <= prim_site <= 119 then sitewho = 20060;
    else if 90 <= prim_site <= 99 then sitewho = 20070;
    else if 100 <= prim_site <= 109 then sitewho = 20080;
    else if 130 <= prim_site <= 139 or prim_site = 129 then sitewho = 20090;
    else if prim_site in (140,142,148) then sitewho = 20100;
    else if 150 <= prim_site <= 159 then sitewho = 21010;
    else if 160 <= prim_site <= 169 then sitewho = 21020;
    else if 170 <= prim_site <= 179 then sitewho = 21030;
    else if prim_site = 180 then sitewho = 21041;
    else if prim_site = 181 then sitewho = 21042;
    else if prim_site = 182 then sitewho = 21043;
    else if prim_site = 183 then sitewho = 21044;
    else if prim_site = 184 then sitewho = 21045;
    else if prim_site = 185 then sitewho = 21046;
    else if prim_site = 186 then sitewho = 21047;
    else if prim_site = 187 then sitewho = 21048;
    else if 188 <= prim_site <= 189 or prim_site = 260 then sitewho = 21049;
    else if prim_site = 199 then sitewho = 21051;
    else if prim_site = 209 then sitewho = 21052;
    else if 210 <= prim_site <= 218 then sitewho = 21060;
    else if prim_site = 220 then sitewho = 21071;
    else if prim_site = 221 then sitewho = 21072;
    else if prim_site = 239 then sitewho = 21080;
    else if 240 <= prim_site <= 249 then sitewho = 21090;
    else if 250 <= prim_site <= 259 then sitewho = 21100;
    else if prim_site = 480 then sitewho = 21110;
    else if 481 <= prim_site <= 482 then sitewho = 21120;
    else if 268 <= prim_site <= 269 or prim_site = 488 then sitewho = 21130;
    else if 300 <= prim_site <= 301 or 310 <= prim_site <= 319 then sitewho = 22010;
    else if 320 <= prim_site <= 329 then sitewho = 22020;
    else if 340 <= prim_site <= 349 then sitewho = 22030;
    else if prim_site = 384 then sitewho = 22050;
    else if 381 <= prim_site <= 383 or prim_site in (339,388,390,398,399) then sitewho = 22060;
    else if 400 <= prim_site <= 409 or 410 <= prim_site <= 419 then sitewho = 23000;
    else if prim_site = 380 or 470 <= prim_site <= 479 or 490 <= prim_site <= 499 then sitewho = 24000;
    else if 500 <= prim_site <= 509 then sitewho = 26000;
    else if 530 <= prim_site <= 539 then sitewho = 27010;
    else if 540 <= prim_site <= 549 then sitewho = 27020;
    else if prim_site = 559 then sitewho = 27030;
    else if prim_site = 569 then sitewho = 27040;
    else if prim_site = 529 then sitewho = 27050;
    else if 510 <= prim_site <= 519 then sitewho = 27060;
    else if 570 <= prim_site <= 579 or prim_site = 589 then sitewho = 27070;
    else if prim_site = 619 then sitewho = 28010;
    else if 620 <= prim_site <= 629 then sitewho = 28020;
    else if 600 <= prim_site <= 609 then sitewho = 28030;
    else if 630 <= prim_site <= 639 then sitewho = 28040;
    else if 670 <= prim_site <= 679 then sitewho = 29010;
    else if prim_site in (649,659) then sitewho = 29020;
    else if prim_site = 669 then sitewho = 29030;
    else if 680 <= prim_site <= 689 then sitewho = 29040;
    else if 690 <= prim_site <= 699 then sitewho = 30000;
    else if 700 <= prim_site <= 709 or 720 <= prim_site <= 729 then sitewho = 31040;
    else if prim_site = 739 then sitewho = 32010;
    else if prim_site = 379 or 740 <= prim_site <= 749 or 750 <= prim_site <= 759 then sitewho = 32020;
    else if 420 <= prim_site <= 424 or 760 <= prim_site <= 768 or 770 <= prim_site <= 779 or prim_site = 809 then sitewho = 37000;
    else if 440 <= prim_site <= 449 then do;
      if 8720 <= hist_o_3 <= 8790 then sitewho = 25010;
      else sitewho = 25020;
      end;
    else if 710 <= prim_site <= 719 then do;
      if 9530 <= hist_o_3 <= 9539 then sitewho = 31040;
      else sitewho = 31010;
      end;
    end;
run;

data all;
  set all;
  seer_csdc = -1;     /* initialize value */
  if seqnum = 0 then SeqType = 0;
  else if 1 <= seqnum <= 59 then SeqType = 1;  /* changed from seqnum = 1 on 4/6/2020 */
  else do; seer_csdc = 9; SeqType = 9; end;
  if seer_csdc ^= 9 and codver ^= 0 then do; /* if dead */
    /* first do all of the non-site-specific checks */
    if SeqType = 0 then do;
      if codver = 8 then do;
        if 140 <= cod89_3dig <= 239 then seer_csdc = 1; /* any cancer */
        end;
      if codver = 9 then do;
        if (140 <= cod89_3dig <= 239) or (cod89_4dig = 0422) then seer_csdc = 1; /* any cancer or HIV */
        end;
      if codver = 1 then do;
        if (cod10char = 'C') or (cod10char = 'D' and cod10_2dig <= 48) or (cod10char = 'B' and cod10_2dig = 21) then seer_csdc = 1; /* any cancer or HIV */
        end;
      end; /* SeqType = 0 */
    else do; /* SeqType = 1 */
      if codver = 8 or codver = 9 then do;
        if cod89_3dig = 199 then seer_csdc = 1; /* unknown primary */
        end;
      else if codver = 1 then do;
        if (cod10char = 'C' and (cod10_3dig = 798 or cod10_2dig = 80 or cod10_2dig = 97)) or (cod10char = 'D' and cod10_3dig = 489) then seer_csdc = 1; /* unknown primary */
        end;
      /* footnotes from bottoms of subsequent cancer pages for melanoma of any site */
      if 8720 <= hist_o_3 <= 8799 then do;  /* melanoma of any site */
        if codver = 8 and (cod89_3dig = 172 or cod89_4dig = 2169 or cod89_4dig = 2322) then seer_csdc = 1;
        else if codver = 9 and (cod89_3dig = 172 or cod89_3dig = 216 or cod89_3dig = 232) then seer_csdc = 1;
        else if codver = 1 and ((cod10char = 'C' and cod10_2dig = 43) or (cod10char = 'D' and (cod10_2dig = 3 or cod10_2dig = 22))) then seer_csdc = 1;
        end; /* melanoma */
      end; /* SeqType = 1 */
    end; /* codver ^= 0 */
  else if seer_csdc ^= 9 then seer_csdc = 0; /* alive */

  if codver = 1 and seqtype = 1 then do; /* have to handle miscellaneous special - some of these hists are Leukemia - so don't check for site rec = Misc here */
    if (hist_o_3 = 9950 or (9960 <= hist_o_3 <= 9964) or (9980 <= hist_o_3 <= 9989)) then do;
      if ((cod10char = 'C' and (cod10_2dig = 77 or (81 <= cod10_2dig <= 96))) or (cod10char = 'D' and (cod10_2dig = 36 or (45 <= cod10_2dig <= 47)))) then seer_csdc = 1;
      end;
    else if sitewho = 37000 then do;
      if (cod10char = 'C') or (cod10char = 'D' and cod10_2dig <= 48) or (cod10char = 'D' and cod10_3dig = 619) then seer_csdc = 1; /* Misc other */
      end;
    end;
run;

data incods;
  infile datalines dlm = '~';
  length cod3dig cod4dig $ 200;
  input codver seqtype sitewho cod3dig cod4dig;
  datalines;
1~0~20010~B20,B22-B24~ ~Lip
1~0~20020~B20,B22-B24~ ~Tongue
1~0~20030~B20,B22-B24~ ~SalivaryGland
1~0~20040~B20,B22-B24~ ~FloorofMouth
1~0~20050~B20,B22-B24~ ~GumandOtherMouth
1~0~20060~B20,B22-B24~ ~Nasopharynx
1~0~20070~B20,B22-B24~ ~Tonsil
1~0~20080~B20,B22-B24~ ~Oropharynx
1~0~20090~B20,B22-B24~ ~Hypopharynx
1~0~20100~B20,B22-B24~ ~OtherOralCavityandPharynx
1~0~21010~K20-K31,K51-K57,K92~ ~Esophagus
1~0~21020~K20-K31,K51-K57,K92~ ~Stomach
1~0~21030~K20-K31,K35-K63,K90-K93~ ~SmallIntestine
1~0~21041~K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~ ~Cecum
1~0~21042~K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~ ~Appendix
1~0~21043~K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~ ~AscendingColon
1~0~21044~K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~ ~HepaticFlexure
1~0~21045~K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~ ~TransverseColon
1~0~21046~K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~ ~SplenicFlexure
1~0~21047~K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~ ~DescendingColon
1~0~21048~K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~ ~SigmoidColon
1~0~21049~K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~ ~LargeIntestine,NOS
1~0~21051~K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~ ~RectosigmoidJunction
1~0~21052~K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~ ~Rectum
1~0~21060~B20,B22-B24,K20-K31,K51-K57,K62,K92~ ~Anus,AnalCanalandAnorectum
1~0~21071~K20-K31,K51-K57,K70-K76,K92~ ~Liver
1~0~21072~K20-K31,K51-K57,K70-K76,K92~ ~IntrahepaticBileDuct
1~0~21080~K20-K31,K51-K57,K80-K83,K92~ ~Gallbladder
1~0~21090~K20-K31,K51-K57,K80-K83,K92~ ~OtherBiliary
1~0~21100~K20-K31,K51-K57,K80-K83,K85-K86,K92~ ~Pancreas
1~0~21110~K20-K31,K51-K57,K92~ ~Retroperitoneum
1~0~21120~K20-K31,K51-K57,K92~ ~Peritoneum,OmentumandMesentery
1~0~21130~K20-K31,K51-K57,K92~ ~OtherDigestiveOrgans
1~0~26000~N61-N64~ ~Breast
1~0~27010~B20,B22-B24,N71-N85~ ~CervixUteri
1~0~27020~N71-N85~ ~CorpusUteri
1~0~27030~N71-N85~ ~Uterus,NOS
1~0~27040~N71-N85~ ~Ovary
1~0~27050~N71-N85~ ~Vagina
1~0~27060~N71-N85~ ~Vulva
1~0~27070~N71-N85~ ~OtherFemaleGenitalOrgans
1~0~28010~N40-N50~ ~Prostate
1~0~28020~N40-N50~ ~Testis
1~0~28030~N40-N50~ ~Penis
1~0~28040~N40-N50~ ~OtherMaleGenitalOrgans
1~0~29010~N17-N19,N28,N39-N40~ ~UrinaryBladder
1~0~29020~N17-N19,N28,N39-N40~ ~KidneyandRenalPelvis
1~0~29030~N17-N19~ ~Ureter
1~0~29040~N17-N19~ ~OtherUrinaryOrgans
1~0~33011~B20,B22-B24~ ~Hodgkin-Nodal
1~0~33012~B20,B22-B24~ ~Hodgkin-Extranodal
1~0~33041~B20,B22-B24~ ~NHL-Nodal
1~0~33042~B20,B22-B24~ ~NHL-Extranodal
1~0~36020~B20,B22-B24~ ~KaposiSarcoma
1~1~20010~B20-B24,C00-C15,C31-C32,D10-D11~C410-C411,C440,C443-C444,C449,C490,C499,C760,D000,D030,D033,D034,D040,D043,D044,D210,D220,D223,D224,D230,D233,D234,D370~Lip
1~1~20020~B20-B24,C00-C15,C31-C32,D10-D11~C410-C411,C440,C443-C444,C449,C490,C499,C760,D000,D030,D033,D034,D040,D043,D044,D210,D220,D223,D224,D230,D233,D234,D370~Tongue
1~1~20030~B20-B24,C00-C15,C31-C32,D10-D11~C410-C411,C440,C443-C444,C449,C490,C499,C760,D000,D030,D033,D034,D040,D043,D044,D210,D220,D223,D224,D230,D233,D234,D370~SalivaryGland
1~1~20040~B20-B24,C00-C15,C31-C32,D10-D11~C410-C411,C440,C443-C444,C449,C490,C499,C760,D000,D030,D033,D034,D040,D043,D044,D210,D220,D223,D224,D230,D233,D234,D370~FloorofMouth
1~1~20050~B20-B24,C00-C15,C31-C32,D10-D11~C410-C411,C440,C443-C444,C449,C490,C499,C760,D000,D030,D033,D034,D040,D043,D044,D210,D220,D223,D224,D230,D233,D234,D370~GumandOtherMouth
1~1~20060~B20-B24,C00-C15,C31-C32,D10-D11~C410-C411,C440,C443-C444,C449,C490,C499,C760,D000,D030,D033,D034,D040,D043,D044,D210,D220,D223,D224,D230,D233,D234,D370~Nasopharynx
1~1~20070~B20-B24,C00-C15,C31-C32,D10-D11~C410-C411,C440,C443-C444,C449,C490,C499,C760,D000,D030,D033,D034,D040,D043,D044,D210,D220,D223,D224,D230,D233,D234,D370~Tonsil
1~1~20080~B20-B24,C00-C15,C31-C32,D10-D11~C410-C411,C440,C443-C444,C449,C490,C499,C760,D000,D030,D033,D034,D040,D043,D044,D210,D220,D223,D224,D230,D233,D234,D370~Oropharynx
1~1~20090~B20-B24,C00-C15,C31-C32,D10-D11~C410-C411,C440,C443-C444,C449,C490,C499,C760,D000,D030,D033,D034,D040,D043,D044,D210,D220,D223,D224,D230,D233,D234,D370~Hypopharynx
1~1~20100~B20-B24,C00-C15,C31-C32,D10-D11~C410-C411,C440,C443-C444,C449,C490,C499,C760,D000,D030,D033,D034,D040,D043,D044,D210,D220,D223,D224,D230,D233,D234,D370~OtherOralCavityandPharynx
1~1~21010~C15-C16,C26,K20-K31,K51-K57,K92~D001,D130,D371-D379~Esophagus
1~1~21020~C14-C16,C26,K20-K31,K51-K57,K92~D002,D131,D371-D379~Stomach
1~1~21030~C17-C21,C26,K35-K63,K90-K93~C784,D014,D132,D133,D371-D379~SmallIntestine
1~1~21041~C17-C21,C26,D12,K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~C785,D010-D012,D371-D379~Cecum
1~1~21042~C17-C21,C26,D12,K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~C785,D010-D012,D371-D379~Appendix
1~1~21043~C17-C21,C26,D12,K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~C785,D010-D012,D371-D379~AscendingColon
1~1~21044~C17-C21,C26,D12,K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~C785,D010-D012,D371-D379~HepaticFlexure
1~1~21045~C17-C21,C26,D12,K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~C785,D010-D012,D371-D379~TransverseColon
1~1~21046~C17-C21,C26,D12,K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~C785,D010-D012,D371-D379~SplenicFlexure
1~1~21047~C17-C21,C26,D12,K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~C785,D010-D012,D371-D379~DescendingColon
1~1~21048~C17-C21,C26,D12,K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~C785,D010-D012,D371-D379~SigmoidColon
1~1~21049~C17-C21,C26,D12,K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~C785,D010-D012,D371-D379~LargeIntestine,NOS
1~1~21051~C17-C21,C26,D12,K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~C785,D010-D012,D371-D379~RectosigmoidJunction
1~1~21052~C17-C21,C26,D12,K20-K31,K35-K38,K51-K57,K62-K63,K65-K66,K92~C785,D010-D012,D371-D379~Rectum
1~1~21060~B21,C17-C21,C26,D12,K20-K31,K51-K57,K62,K92~C445,C785,D013,D035,D045,D225,D235,D371-D379,D485~Anus,AnalCanalandAnorectum
1~1~21071~C22,C26,K20-K31,K51-K57,K70-K76,K92~C787,D015,D134,D371-D379~Liver
1~1~21072~C22,C26,K20-K31,K51-K57,K70-K76,K92~C787,D015,D134,D371-D379~IntrahepaticBileDuct
1~1~21080~C23-C24,C26,K20-K31,K51-K57,K80-K83,K92~D015,D135,D139,D371-D379~Gallbladder
1~1~21090~C23-C24,C26,K20-K31,K51-K57,K80-K83,K92~D015,D135,D139,D371-D379~OtherBiliary
1~1~21100~C25-C26,K20-K31,K51-K57,K80-K83,K92~D017,D136,D137,D371-D379~Pancreas
1~1~21110~C26,C48,K20-K31,K51-K57,K92~C786,D017,D139,D200,D371-D379,D483~Retroperitoneum
1~1~21120~C26,C48,K20-K31,K51-K57,K92~C451,C786,D017,D139,D201,D371-D379,D484~Peritoneum,OmentumandMesentery
1~1~21130~C26,D01,K20-K31,K51-K57,K92~C788,D139,D371-D379~OtherDigestiveOrgans
1~1~22010~C30-C31,C39,D38~C442,D023,D032,D042,D140,D222,D232,D481~Nose,NasalCavityandMiddleEar
1~1~22020~C32-C34,C39,D38~D020,D141~Larynx
1~1~22030~C32-C34,C39,D15,D38~C780,D022,D143,D144~LungandBronchus
1~1~22050~C33,C38-C39,C45,D38~C782,D023,D144~Pleura
1~1~22060~C32-C41,D38~C780-C783,D021,D024,D142,D144~Trachea,MediastinumandOtherRespiratoryOrgans
1~1~23000~C40-C41,D16~C795,D480~BonesandJoints
1~1~24000~C47,C49,C72,D15-D21~C452,D481-D482,D487~SoftTissueincludingHeart
1~1~25010~C43-C44,D03-D04,D22-D23~C792~MelanomaoftheSkin
1~1~25020~C43-C44,C46,D04,D22-D23,D45~C792~OtherNon-EpithelialSkin
1~1~26000~C50,D05,D24,N61-N64~C445,D225,D485,D486~Breast
1~1~27010~B20-B24,C51-C57,D06,D25-D26,D39,N71-N85~ ~CervixUteri
1~1~27020~C51-C57,D25-D26,D39,N71-N85~D070,D073~CorpusUteri
1~1~27030~C51-C57,D25-D26,D39,N71-N85~D070,D073~Uterus,NOS
1~1~27040~C51-C57,C79,D27,D39,N71-N85~D073~Ovary
1~1~27050~C51-C57,D28,N71-N85~D072,D397~Vagina
1~1~27060~C51-C57,D28,N71-N85~D071,D397~Vulva
1~1~27070~C51-C58,D25-D26,D28,D39,N71-N85~D073~OtherFemaleGenitalOrgans
1~1~28010~C60-C63,D40,N40-N50~D075,D291~Prostate
1~1~28020~C60-C63,D40,N40-N50~D076,D292~Testis
1~1~28030~C60-C63,D40,N40-N50~D074,D290~Penis
1~1~28040~C60-C63,D40,N40-N50~D076,D293-D299~OtherMaleGenitalOrgans
1~1~29010~C64-C68,N17-N19,N28,N39,N40~C791,D090,D303,D414~UrinaryBladder
1~1~29020~C64-C68,N17-N19,N28,N39,N40~C790,D091,D300-D301,D410-D411~KidneyandRenalPelvis
1~1~29030~C64-C68,N17-N19~D091,D302,D412~Ureter
1~1~29040~C64-C68,D41,N17-N19~C791,D091,D304,D309~OtherUrinaryOrgans
1~1~30000~C69,D31~D031,D041,D092,D221,D231,D481,D487~EyeandOrbit
1~1~31010~C70-C72,D32-D33,D42-D43~C793-C794~Brain
1~1~31040~C70-C72,D32-D33,D42-D43~C793-C794~CranialNervesOtherNervousSystem
1~1~32010~C73,D34-D35~D093,D440~Thyroid
1~1~32020~C37,C74,C75,D35~C797,D093,D150,D384,D441-D449~OtherEndocrineincludingThymus
1~1~33011~B20-B24,C77,C81-C96,D36,D47~ ~Hodgkin-Nodal
1~1~33012~B20-B24,C77,C81-C96,D36,D47~ ~Hodgkin-Extranodal
1~1~33041~B20-B24,C77,C81-C96,D36,D47~ ~NHL-Nodal
1~1~33042~B20-B24,C77,C81-C96,D36,D47~ ~NHL-Extranodal
1~1~34000~C90~ ~Myeloma
1~1~35011~C82-C85,C88,C81-C96,D46,D47~ ~AcuteLymphocyticLeukemia
1~1~35012~C82-C85,C88,C81-C96,D46,D47~ ~ChronicLymphocyticLeukemia
1~1~35013~C82-C85,C88,C81-C96,D46,D47~ ~OtherLymphocyticLeukemia
1~1~35021~C82-C85,C88,C81-C96,D46,D47~ ~AcuteMyeloidLeukemia
1~1~35022~C82-C85,C88,C81-C96,D46,D47~ ~AcuteMyeloidLeukemia
1~1~35023~C82-C85,C88,C81-C96,D46,D47~ ~OtherMyeloid/MonocyticLeukemia
1~1~35031~C82-C85,C88,C81-C96,D46,D47~ ~OtherMyeloid/MonocyticLeukemia
1~1~35041~C82-C85,C88,C81-C96,D46,D47~ ~OtherAcuteLeukemia
1~1~35043~C82-C85,C88,C81-C96,D46,D47~ ~Aleukemic,SubleukemicandNOS
1~1~36010~C34,C38-C39,C45~ ~Mesothelioma
1~1~36020~B20-B24,C46~ ~KaposiSarcoma
8~0~21010~530-537,560-562~4442,5631,5699,7845,7857,9909~Esophagus
8~0~21020~530-537,560-562~4442,5631,5699,7845,7857,9909~Stomach
8~0~21030~530-537,560-562~4442,5631,5699,7845,7857,9909~SmallIntestine
8~0~21041~530-543,560-562,568-569~4442,5631,5679,7845,7857,9909~Cecum
8~0~21042~530-543,560-562,568-569~4442,5631,5679,7845,7857,9909~Appendix
8~0~21043~530-543,560-562,568-569~4442,5631,5679,7845,7857,9909~AscendingColon
8~0~21044~530-543,560-562,568-569~4442,5631,5679,7845,7857,9909~HepaticFlexure
8~0~21045~530-543,560-562,568-569~4442,5631,5679,7845,7857,9909~TransverseColon
8~0~21046~530-543,560-562,568-569~4442,5631,5679,7845,7857,9909~SplenicFlexure
8~0~21047~530-543,560-562,568-569~4442,5631,5679,7845,7857,9909~DescendingColon
8~0~21048~530-543,560-562,568-569~4442,5631,5679,7845,7857,9909~SigmoidColon
8~0~21049~530-543,560-562,568-569~4442,5631,5679,7845,7857,9909~LargeIntestine,NOS
8~0~21051~530-543,560-562,568-569~4442,5631,5679,7845,7857,9909~RectosigmoidJunction
8~0~21052~530-543,560-562,568-569~4442,5631,5679,7845,7857,9909~Rectum
8~0~21060~530-537,560-562,569~4442,5631,7845,7857,9909~Anus,AnalCanalandAnorectum
8~0~21071~530-537,560-562,570-573~4442,5631,5699,7845,7857,9909~Liver
8~0~21072~530-537,560-562,570-573~4442,5631,5699,7845,7857,9909~IntrahepaticBileDuct
8~0~21080~530-537,560-562,574-576~4442,5631,5699,7845,7857,9909,9989~Gallbladder
8~0~21090~530-537,560-562,574-576~4442,5631,5699,7845,7857,9909,9989~OtherBiliary
8~0~21100~530-537,560-562,577~4442,5631,5699,7845,7857,9909~Pancreas
8~0~21110~530-537,560-562~4442,5631,5699,7845,7857,9909~Retroperitoneum
8~0~21120~530-537,560-562~4442,5631,5699,7845,7857,9909~Peritoneum,OmentumandMesentery
8~0~21130~530-537,560-562~4442,5631,5699,7845,7857,9909~OtherDigestiveOrgans
8~0~25020~ ~7572~OtherNon-EpithelialSkin
8~0~26000~610-611~7867~Breast
8~0~27010~612-614,620,622,624-625~5960,6077,6150,6152-6159,6160-6161,6169,6230,6233-6239,6266,6299~CervixUteri
8~0~27020~612-614,620,622,624-625~5960,6077,6150,6152-6159,6160-6161,6169,6230,6233-6239,6266,6299~CorpusUteri
8~0~27030~612-614,620,622,624-625~5960,6077,6150,6152-6159,6160-6161,6169,6230,6233-6239,6266,6299~Uterus,NOS
8~0~27040~612-614,620,622,624-625~5960,6077,6150,6152-6159,6160-6161,6169,6230,6233-6239,6266,6299~Ovary
8~0~27050~612-614,620,622,624-625~5960,6077,6150,6152-6159,6160-6161,6169,6230,6233-6239,6266,6299~Vagina
8~0~27060~612-614,620,622,624-625~5960,6077,6150,6152-6159,6160-6161,6169,6230,6233-6239,6266,6299~Vulva
8~0~27070~612-614,620,622,624-625~5960,6077,6150,6152-6159,6160-6161,6169,6230,6233-6239,6266,6299~OtherFemaleGenitalOrgans
8~0~28010~600-607~7866~Prostate
8~0~28020~600-607~7866~Testis
8~0~28030~600-607~7866~Penis
8~0~28040~600-607~7866~OtherMaleGenitalOrgans
8~0~29010~580,582,599~4443,5931-5935~UrinaryBladder
8~0~29020~580,582,599~4443,5931-5935~KidneyandRenalPelvis
8~0~29030~580,582~5931,5932~Ureter
8~0~29040~580,582,600~5931,5932~OtherUrinaryOrgans
8~0~32010~ ~2419~Thyroid
8~0~33011~279~6959,7572~Hodgkin-Nodal
8~0~33012~279~6959,7572~Hodgkin-Extranodal
8~0~33041~279~6959,7572~NHL-Nodal
8~0~33042~279~6959,7572~NHL-Extranodal
8~0~34000~279~ ~Myeloma
8~0~35011~279~6959,7434,7572~AcuteLymphocyticLeukemia
8~0~35012~279~6959,7434,7572~ChronicLymphocyticLeukemia
8~0~35013~279~6959,7434,7572~OtherLymphocyticLeukemia
8~0~35021~279~6959,7434,7572~AcuteMyeloidLeukemia
8~0~35022~279~6959,7434,7572~AcuteMyeloidLeukemia
8~0~35023~279~6959,7434,7572~OtherMyeloid/MonocyticLeukemia
8~0~35031~279~6959,7434,7572~OtherMyeloid/MonocyticLeukemia
8~0~35041~279~6959,7434,7572~OtherAcuteLeukemia
8~0~35043~279~6959,7434,7572~Aleukemic,SubleukemicandNOS
8~0~36020~ ~7572~KaposiSarcoma
8~0~37000~284~2759,7572~Miscellaneous
8~1~20010~140-149,210,215~1602-1609,1700,1710,1719,1730,1733,1734,1739,1959,2169,2303,2305,2307,2309,2310,2311,2313,2315,2322,2390~Lip
8~1~20020~140-149,210,215~1602-1609,1700,1710,1719,1730,1733,1734,1739,1959,2169,2303,2305,2307,2309,2310,2311,2313,2315,2322,2390~Tongue
8~1~20030~140-149,210,215~1602-1609,1700,1710,1719,1730,1733,1734,1739,1959,2169,2303,2305,2307,2309,2310,2311,2313,2315,2322,2390~SalivaryGland
8~1~20040~140-149,210,215~1602-1609,1700,1710,1719,1730,1733,1734,1739,1959,2169,2303,2305,2307,2309,2310,2311,2313,2315,2322,2390~FloorofMouth
8~1~20050~140-149,210,215~1602-1609,1700,1710,1719,1730,1733,1734,1739,1959,2169,2303,2305,2307,2309,2310,2311,2313,2315,2322,2390~GumandOtherMouth
8~1~20060~140-149,210,215~1602-1609,1700,1710,1719,1730,1733,1734,1739,1959,2169,2303,2305,2307,2309,2310,2311,2313,2315,2322,2390~Nasopharynx
8~1~20070~140-149,210,215~1602-1609,1700,1710,1719,1730,1733,1734,1739,1959,2169,2303,2305,2307,2309,2310,2311,2313,2315,2322,2390~Tonsil
8~1~20080~140-149,210,215~1602-1609,1700,1710,1719,1730,1733,1734,1739,1959,2169,2303,2305,2307,2309,2310,2311,2313,2315,2322,2390~Oropharynx
8~1~20090~140-149,210,215~1602-1609,1700,1710,1719,1730,1733,1734,1739,1959,2169,2303,2305,2307,2309,2310,2311,2313,2315,2322,2390~Hypopharynx
8~1~20100~140-149,210,215~1602-1609,1700,1710,1719,1730,1733,1734,1739,1959,2169,2303,2305,2307,2309,2310,2311,2313,2315,2322,2390~OtherOralCavityandPharynx
8~1~21010~150-151,159,530-537,560-562~1536,2110,2300,2303,2305,2307,2309,2390,4442,5631,5699,7845,7857,9909~Esophagus
8~1~21020~150-151,159,530-537,560-562~1536,2111,2301,2303,2305,2307,2309,2390,4442,5631,5699,7845,7857,9909~Stomach
8~1~21030~152-155,159,530-537,560-562~1974,1978,2112,2302,2303,2305,2307,2309,4442,5631,5699,7845,7857,9909~SmallIntestine
8~1~21041~152-155,159,211,530-543,560-562,568,569~1975,1978,2303-2305,2307,2309,4442,5631,5679,7845,7857,9909~Cecum
8~1~21042~152-155,159,211,530-543,560-562,568,569~1975,1978,2303-2305,2307,2309,4442,5631,5679,7845,7857,9909~Appendix
8~1~21043~152-155,159,211,530-543,560-562,568,569~1975,1978,2303-2305,2307,2309,4442,5631,5679,7845,7857,9909~AscendingColon
8~1~21044~152-155,159,211,530-543,560-562,568,569~1975,1978,2303-2305,2307,2309,4442,5631,5679,7845,7857,9909~HepaticFlexure
8~1~21045~152-155,159,211,530-543,560-562,568,569~1975,1978,2303-2305,2307,2309,4442,5631,5679,7845,7857,9909~TransverseColon
8~1~21046~152-155,159,211,530-543,560-562,568,569~1975,1978,2303-2305,2307,2309,4442,5631,5679,7845,7857,9909~SplenicFlexure
8~1~21047~152-155,159,211,530-543,560-562,568,569~1975,1978,2303-2305,2307,2309,4442,5631,5679,7845,7857,9909~DescendingColon
8~1~21048~152-155,159,211,530-543,560-562,568,569~1975,1978,2303-2305,2307,2309,4442,5631,5679,7845,7857,9909~SigmoidColon
8~1~21049~152-155,159,211,530-543,560-562,568,569~1975,1978,2303-2305,2307,2309,4442,5631,5679,7845,7857,9909~LargeIntestine,NOS
8~1~21051~152-155,159,211,530-543,560-562,568,569~1975,1978,2303-2305,2307,2309,4442,5631,5679,7845,7857,9909~RectosigmoidJunction
8~1~21052~152-155,159,211,530-543,560-562,568,569~1975,1978,2303-2305,2307,2309,4442,5631,5679,7845,7857,9909~Rectum
8~1~21060~152-155,159,211,530-537,560-562,569~1736,1975,2169,2303-2305,2307,2309,2322,4442,5631,7845,7857,9909~Anus,AnalCanalandAnorectum
8~1~21071~155,159,530-537,560-562,570-573~1536,1977,1978,2115,2303,2305,2307,2309,4442,5631,5699,7845,7857,9909~Liver
8~1~21072~155,159,530-537,560-562,570-573~1536,1977,1978,2115,2303,2305,2307,2309,4442,5631,5699,7845,7857,9909~IntrahepaticBileDuct
8~1~21080~156,159,530-537,560-562,574-576~1536,2115,2119,2303,2305,2307,2309,4442,5631,5699,7845,7857,9909,9989~Gallbladder
8~1~21090~156,159,530-537,560-562,574-576~1536,2115,2119,2303,2305,2307,2309,4442,5631,5699,7845,7857,9909,9989~OtherBiliary
8~1~21100~157,159,530-537,560-562,577~1536,2116,2303,2305,2307,2309,4442,5631,5699,7845,7857,9909~Pancreas
8~1~21110~158-159,530-537,560-562~1536,1976,2117,2119,2303,2305,2307,2309,4442,5631,5699,7845,7857,9909~Retroperitoneum
8~1~21120~158-159,530-537,560-562~1536,1976,2117,2119,2303,2305,2307,2309,4442,5631,5699,7845,7857,9909~Peritoneum,OmentumandMesentery
8~1~21130~159,230,530-537,560-562~1536,1979,2119,2390,4442,5631,5699,7845,7857,9909~OtherDigestiveOrgans
8~1~22010~160~1620,1621,1639,1732,2120,2169,2310,2320,2321,2311,2313,2315~Nose,NasalCavityandMiddleEar
8~1~22020~161-162~1639,2121,2310,2311,2313,2315~Larynx
8~1~22030~161-162,215~1639,1970,2122-2125,2129,2261,2310,2311,2313,2315~LungandBronchus
8~1~22050~ ~1620,1630,1631,1639,1711,1942,1972,2129,2310,2311,2313,2315~Pleura
8~1~22060~161-163,170~1711,1942,1970-1973,2122,2129,2309,2310,2311,2313,2315,2391~Trachea,MediastinumandOtherRespiratoryOrgans
8~1~23000~170~1985,2139,2320~BonesandJoints
8~1~24000~171,214-215~1922,1929,2129,2139,2261,2399~SoftTissueincludingHeart
8~1~25010~172-173~1982,2169,2322~MelanomaoftheSkin
8~1~25020~172-173,208~1982,2169,2322,7572~OtherNon-EpithelialSkin
8~1~26000~174,217,233,610-611~1736,2169,2322,7867~Breast
8~1~27010~180,182-184,218-219,235,612-614,620,622,624-625~2201,2212,2340,2349,2369,5960,6077,6150,6152-6159,6160-6161,6169,6230,6233-6239,6266,6299~CervixUteri
8~1~27020~180,182-184,218-219,235,612-614,620,622,624-625~2201,2212,2349,2369,5960,6077,6150,6152-6159,6160-6161,6169,6230,6233-6239,6266,6299~CorpusUteri
8~1~27030~180,182-184,218-219,235,612-614,620,622,624-625~2201,2212,2349,2369,5960,6077,6150,6152-6159,6160-6161,6169,6230,6233-6239,6266,6299~Uterus,NOS
8~1~27040~180,182-184,219,235,612-614,620,622,624-625~1989,2201,2209,2212,2349,2369,5960,6077,6150,6152-6159,6160-6161,6169,6230,6233-6239,6266,6299~Ovary
8~1~27050~180,182-184,219,221,612-614,620,622,624-625~2201,2369,5960,6077,6150,6152-6159,6160-6161,6169,6230,6233-6239,6266,6299~Vagina
8~1~27060~180,182-184,219,221,234,612-614,620,622,624-625~2201,2369,5960,6077,6150,6152-6159,6160-6161,6169,6230,6233-6239,6266,6299~Vulva
8~1~27070~180,182-184,218-219,221,235,612-614,620,622,624-625~2201,2349,2369,5960,6077,6150,6152-6159,6160-6161,6169,6230,6233-6239,6266,6299~OtherFemaleGenitalOrgans
8~1~28010~185-187,600-607~2370,2372,7866~Prostate
8~1~28020~185-187,600-607~2220,2370,2372,7866~Testis
8~1~28030~185-187,600-607~2221,2370-2372,7866~Penis
8~1~28040~185-187,600-607~2169,2228,2229,2370,2372,7866~OtherMaleGenitalOrgans
8~1~29010~188-189,580,582,599~1981,2233,2376,4443,5931-5935~UrinaryBladder
8~1~29020~188-189,223-224,580,582,599~1981,2373,2376,2379,4443,5931-5935~KidneyandRenalPelvis
8~1~29030~188-189,580,582~2232,2373,2379,5931,5932~Ureter
8~1~29040~188-189,580,582,600~2238-2239,2370,2372,2379,5931,5932~OtherUrinaryOrgans
8~1~30000~190,224~2169,2321,2322,2380,2399~EyeandOrbit
8~1~31010~191,225~1920-1922,1929,1983,1984,2262,2391~Brain
8~1~31040~191,225~1920-1922,1929,1983,1984,2262,2391~CranialNervesOtherNervousSystem
8~1~32010~193~2260,2262-2269,2391,2399,2419~Thyroid
8~1~32020~194,226~1989,2315,2321,2391,2399~OtherEndocrineincludingThymus
8~1~33011~196,200-209,228,279~2272,6959,7572~Hodgkin-Nodal
8~1~33012~196,200-209,228,279~2272,6959,7572~Hodgkin-Extranodal
8~1~33041~196,200-209,228,279~2272,6959,7572~NHL-Nodal
8~1~33042~196,200-209,228,279~2272,6959,7572~NHL-Extranodal
8~1~34000~203,279~2079~Myeloma
8~1~35011~200,202-204,209,279~2069,2079,2262,2381,2389,2391,6959,7434,7572~AcuteLymphocyticLeukemia
8~1~35012~200,202-204,209,279~2069,2079,2262,2381,2389,2391,6959,7434,7572~ChronicLymphocyticLeukemia
8~1~35013~200,202-204,209,279~2069,2079,2262,2381,2389,2391,6959,7434,7572~OtherLymphocyticLeukemia
8~1~35021~200,202-204,209,279~2069,2079,2262,2381,2389,2391,6959,7434,7572~AcuteMyeloidLeukemia
8~1~35022~200,202-204,209,279~2069,2079,2262,2381,2389,2391,6959,7434,7572~AcuteMyeloidLeukemia
8~1~35023~200,202-204,209,279~2069,2079,2262,2381,2389,2391,6959,7434,7572~OtherMyeloid/MonocyticLeukemia
8~1~35031~200,202-204,209,279~2069,2079,2262,2381,2389,2391,6959,7434,7572~OtherMyeloid/MonocyticLeukemia
8~1~35041~200,202-204,209,279~2069,2079,2262,2381,2389,2391,6959,7434,7572~OtherAcuteLeukemia
8~1~35043~200,202-204,209,279~2069,2079,2262,2381,2389,2391,6959,7434,7572~Aleukemic,SubleukemicandNOS
8~1~36010~162-163~1711,1942~Mesothelioma
8~1~36020~ ~7572~KaposiSarcoma
8~1~37000~140-198,200-209,284~2759,7572~Miscellaneous
9~0~20010~043-044~0420-0421,0429~Lip
9~0~20020~043-044~0420-0421,0429~Tongue
9~0~20030~043-044~0420-0421,0429~SalivaryGland
9~0~20040~043-044~0420-0421,0429~FloorofMouth
9~0~20050~043-044~0420-0421,0429~GumandOtherMouth
9~0~20060~043-044~0420-0421,0429~Nasopharynx
9~0~20070~043-044~0420-0421,0429~Tonsil
9~0~20080~043-044~0420-0421,0429~Oropharynx
9~0~20090~043-044~0420-0421,0429~Hypopharynx
9~0~20100~043-044~0420-0421,0429~OtherOralCavityandPharynx
9~0~21010~530-537,556-562,578~ ~Esophagus
9~0~21020~530-537,556-562,578~ ~Stomach
9~0~21030~530-537,556-562,578~ ~SmallIntestine
9~0~21041~530-543,556-562,567-569,578~ ~Cecum
9~0~21042~530-543,556-562,567-569,578~ ~Appendix
9~0~21043~530-543,556-562,567-569,578~ ~AscendingColon
9~0~21044~530-543,556-562,567-569,578~ ~HepaticFlexure
9~0~21045~530-543,556-562,567-569,578~ ~TransverseColon
9~0~21046~530-543,556-562,567-569,578~ ~SplenicFlexure
9~0~21047~530-543,556-562,567-569,578~ ~DescendingColon
9~0~21048~530-543,556-562,567-569,578~ ~SigmoidColon
9~0~21049~530-543,556-562,567-569,578~ ~LargeIntestine,NOS
9~0~21051~530-543,556-562,567-569,578~ ~RectosigmoidJunction
9~0~21052~530-543,556-562,567-569,578~ ~Rectum
9~0~21060~042-044,530-537,556-562,569,578~ ~Anus,AnalCanalandAnorectum
9~0~21071~530-537,556-562,570-573,578~ ~Liver
9~0~21072~530-537,556-562,570-573,578~ ~IntrahepaticBileDuct
9~0~21080~530-537,556-562,574-576,578~ ~Gallbladder
9~0~21090~530-537,556-562,574-576,578~ ~OtherBiliary
9~0~21100~530-537,556-562,577-578~ ~Pancreas
9~0~21110~530-537,556-562,578~ ~Retroperitoneum
9~0~21120~530-537,556-562,578~ ~Peritoneum,OmentumandMesentery
9~0~21130~530-537,556-562,578~ ~OtherDigestiveOrgans
9~0~26000~611~ ~Breast
9~0~27010~043-044,614-621~0420-0421,0429~CervixUteri
9~0~27020~614-621~ ~CorpusUteri
9~0~27030~614-621~ ~Uterus,NOS
9~0~27040~614-621~ ~Ovary
9~0~27050~614-621~ ~Vagina
9~0~27060~614-621~ ~Vulva
9~0~27070~614-621~ ~OtherFemaleGenitalOrgans
9~0~28010~600-608~ ~Prostate
9~0~28020~600-608~ ~Testis
9~0~28030~600-608~ ~Penis
9~0~28040~600-608~ ~OtherMaleGenitalOrgans
9~0~29010~584-586,593,599~ ~UrinaryBladder
9~0~29020~584-586,593,599~ ~KidneyandRenalPelvis
9~0~29030~584-586~ ~Ureter
9~0~29040~584-586~ ~OtherUrinaryOrgans
9~0~33011~043-044~0420-0421,0429~Hodgkin-Nodal
9~0~33012~043-044~0420-0421,0429~Hodgkin-Extranodal
9~0~33041~043-044~0420-0421,0429~NHL-Nodal
9~0~33042~043-044~0420-0421,0429~NHL-Extranodal
9~0~36020~043-044~0420-0421,0429~KaposiSarcoma
9~0~37000~284~2731~Miscellaneous
9~1~20010~042-044,140-149,210,215-216,235~1602-1609,1700,1710,1719,1730,1733,1734,1739,1950,2300,2320,2323-2324~Lip
9~1~20020~042-044,140-149,210,215-216,235~1602-1609,1700,1710,1719,1730,1733,1734,1739,1950,2300,2320,2323-2324~Tongue
9~1~20030~042-044,140-149,210,215-216,235~1602-1609,1700,1710,1719,1730,1733,1734,1739,1950,2300,2320,2323-2324~SalivaryGland
9~1~20040~042-044,140-149,210,215-216,235~1602-1609,1700,1710,1719,1730,1733,1734,1739,1950,2300,2320,2323-2324~FloorofMouth
9~1~20050~042-044,140-149,210,215-216,235~1602-1609,1700,1710,1719,1730,1733,1734,1739,1950,2300,2320,2323-2324~GumandOtherMouth
9~1~20060~042-044,140-149,210,215-216,235~1602-1609,1700,1710,1719,1730,1733,1734,1739,1950,2300,2320,2323-2324~Nasopharynx
9~1~20070~042-044,140-149,210,215-216,235~1602-1609,1700,1710,1719,1730,1733,1734,1739,1950,2300,2320,2323-2324~Tonsil
9~1~20080~042-044,140-149,210,215-216,235~1602-1609,1700,1710,1719,1730,1733,1734,1739,1950,2300,2320,2323-2324~Oropharynx
9~1~20090~042-044,140-149,210,215-216,235~1602-1609,1700,1710,1719,1730,1733,1734,1739,1950,2300,2320,2323-2324~Hypopharynx
9~1~20100~042-044,140-149,210,215-216,235~1602-1609,1700,1710,1719,1730,1733,1734,1739,1950,2300,2320,2323-2324~OtherOralCavityandPharynx
9~1~21010~150-151,159,530-537,556-562,578~2110,2301,2352-2355~Esophagus
9~1~21020~150-151,159,530-537,556-562,578~2111,2302,2352-2355~Stomach
9~1~21030~152-155,159,530-537,556-562,578~1974,2112,2307,2352-2355~SmallIntestine
9~1~21041~152-155,159,211,530-543,556-562,567-569,578~1975,2303,2304,2352-2355~Cecum
9~1~21042~152-155,159,211,530-543,556-562,567-569,578~1975,2303,2304,2352-2355~Appendix
9~1~21043~152-155,159,211,530-543,556-562,567-569,578~1975,2303,2304,2352-2355~AscendingColon
9~1~21044~152-155,159,211,530-543,556-562,567-569,578~1975,2303,2304,2352-2355~HepaticFlexure
9~1~21045~152-155,159,211,530-543,556-562,567-569,578~1975,2303,2304,2352-2355~TransverseColon
9~1~21046~152-155,159,211,530-543,556-562,567-569,578~1975,2303,2304,2352-2355~SplenicFlexure
9~1~21047~152-155,159,211,530-543,556-562,567-569,578~1975,2303,2304,2352-2355~DescendingColon
9~1~21048~152-155,159,211,530-543,556-562,567-569,578~1975,2303,2304,2352-2355~SigmoidColon
9~1~21049~152-155,159,211,530-543,556-562,567-569,578~1975,2303,2304,2352-2355~LargeIntestine,NOS
9~1~21051~152-155,159,211,530-543,556-562,567-569,578~1975,2303,2304,2352-2355~RectosigmoidJunction
9~1~21052~152-155,159,211,530-543,556-562,567-569,578~1975,2303,2304,2352-2355~Rectum
9~1~21060~042,152-155,159,211,530-537,556-562,569,578~1735,1975,2165,2305,2325,2352-2355,2382~Anus,AnalCanalandAnorectum
9~1~21071~155,159,530-537,556-562,570-573,578~1977,2115,2308,2352-2355~Liver
9~1~21072~155,159,530-537,556-562,570-573,578~1977,2115,2308,2352-2355~IntrahepaticBileDuct
9~1~21080~156,159,530-537,556-562,574-576,578~2115,2119,2308,2352-2355~Gallbladder
9~1~21090~156,159,530-537,556-562,574-576,578~2115,2119,2308,2352-2355~OtherBiliary
9~1~21100~157,159,530-537,556-562,577-578~2116,2117,2309,2352-2355~Pancreas
9~1~21110~158,159,530-537,556-562,578~1976,2118,2119,2309,2352-2355~Retroperitoneum
9~1~21120~158,159,530-537,556-562,578~1976,2118,2119,2309,2352-2355~Peritoneum,OmentumandMesentery
9~1~21130~159,230,530-537,556-562,578~1978,2119,2352-2355~OtherDigestiveOrgans
9~1~22010~160,162,165~1732,2120,2162,2318,2322,2356-2359,2381~Nose,NasalCavityandMiddleEar
9~1~22020~161-162,165~2121,2310,2356-2359~Larynx
9~1~22030~161-162,165~1970,2312,2122-2129,2356-2359~LungandBronchus
9~1~22050~164-165~1620,1639,1972,2129,2318,2356-2359~Pleura
9~1~22060~161-170~1970-1973,2122,2129,2311,2356-2359,2391~Trachea,MediastinumandOtherRespiratoryOrgans
9~1~23000~170,213~1985,2380~BonesandJoints
9~1~24000~171~1641,1922,1928,1929,2126-2159,2388~SoftTissueincludingHeart
9~1~25010~172-173,216,232~1982~MelanomaoftheSkin
9~1~25020~172-173,176,216,232~1982,2384~OtherNon-EpithelialSkin
9~1~26000~174,217,611~1735,2165,2330,2382,2383~Breast
9~1~27010~042-044,179-180,182-184,218,219,614-621~2331,2360-2363~CervixUteri
9~1~27020~179-180,182-184,218-219,614-621~2332,2333,2360-2363~CorpusUteri
9~1~27030~179-180,182-184,218-219,614-621~2332,2333,2360-2363~Uterus,NOS
9~1~27040~179-180,182-184,220,614-621~1986,2333,2360-2363~Ovary
9~1~27050~179-180,182-184,221,614-621~2333,2363~Vagina
9~1~27060~179-180,182-184,221,614-621~2331,2363~Vulva
9~1~27070~179-184,218-219,221,614-621~2333,2360-2363~OtherFemaleGenitalOrgans
9~1~28010~185-187,600-608~2222,2334,2364-2366~Prostate
9~1~28020~185-187,600-608~2220,2336,2364-2366~Testis
9~1~28030~185-187,600-608~2221,2335,2364-2366~Penis
9~1~28040~185-187,600-608~2223-2229,2336,2364-2366~OtherMaleGenitalOrgans
9~1~29010~188-189,584-586,593,599~1981,2233,2337,2367~UrinaryBladder
9~1~29020~188-189,223-224,584-586,593,599~1981,2339,2367,2369~KidneyandRenalPelvis
9~1~29030~188-189,584-586~2232,2339,2369~Ureter
9~1~29040~188-189,584-586~1981,2238-2239,2339,2364-2369~OtherUrinaryOrgans
9~1~30000~190,224~2161,2321,2340,2381,2388~EyeandOrbit
9~1~31010~191,225~1920-1922,1928,1929,1983,1984,2370,2374~Brain
9~1~31040~191,225~1920-1922,1928,1929,1983,1984,2370,2374~CranialNervesOtherNervousSystem
9~1~32010~193,226-227~2348,2374~Thyroid
9~1~32020~194,227~1640,1987,2348,2126,2358,2370-2374,2381~OtherEndocrineincludingThymus
9~1~33011~042-044,196,200-208,229~2385,2387~Hodgkin-Nodal
9~1~33012~042-044,196,200-208,229~2385,2387~Hodgkin-Extranodal
9~1~33041~042-044,196,200-208,229~2385,2387~NHL-Nodal
9~1~33042~042-044,196,200-208,229~2385,2387~NHL-Extranodal
9~1~34000~203~ ~Myeloma
9~1~35011~200,202-204,237~2387~AcuteLymphocyticLeukemia
9~1~35012~200,202-204,237~2387~ChronicLymphocyticLeukemia
9~1~35013~200,202-204,237~2387~OtherLymphocyticLeukemia
9~1~35021~200,202-204,237~2387~AcuteMyeloidLeukemia
9~1~35022~200,202-204,237~2387~AcuteMyeloidLeukemia
9~1~35023~200,202-204,237~2387~OtherMyeloid/MonocyticLeukemia
9~1~35031~200,202-204,237~2387~OtherMyeloid/MonocyticLeukemia
9~1~35041~200,202-204,237~2387~OtherAcuteLeukemia
9~1~35043~200,202-204,237~2387~Aleukemic,SubleukemicandNOS
9~1~36010~162-165~ ~Mesothelioma
9~1~36020~042-044,176~ ~KaposiSarcoma
9~1~37000~140-198,200-208,284~2384,2385,2387,2731~Miscellaneous
;
run;

/* parse codes and setup arrays - for each ICD version (8, 9, 10), sequence # (0, 1), and site           */
/* there is a line with ICD-codes that count as death due to that cancer - there are 2 sets of ICD-codes */
/* first is 3-digit codes and the second is 4-digit codes                                                */
/* sequence # 1 codes are used for sequence # 1-59 - 4/6/2020                                            */
data incods;
  set incods;
  array lows_s[30] low_s1-low_s30;
  array highs_s[30] high_s1-high_s30;
  array lows_l[30] low_l1-low_l30;
  array highs_l[30] high_l1-high_l30;
  array chars_s[30] $ char_s1-char_s30;
  array chars_l[30] $ char_l1-char_l30;
  cod3dig=compress(cod3dig);
  len3dig=length(cod3dig);
  cod4dig=compress(cod4dig);
  len4dig=length(cod4dig);
  do i = 1 to 30;
    lows_s[i] = 0;
    highs_s[i]= 0;
    lows_l[i] = 0;
    highs_l[i]= 0;
    chars_s[i] = ' ';
    chars_l[i] = ' ';
    end;
  if codver in (8,9) then do;
    /* set 3 digit values for ICD-8 or 9 */
    numvals = (len3dig+1) / 4;  /* integer division of 043-044,614-621 - len = 15+1/4 = 4 - (4 is to account for the - or ,) */
    numranges = 1;
    do i = 1 to numvals;
      if i = 1 then lows_s[1] = INPUT(SUBSTR(cod3dig,1,3),3.);
      else do;
        if SUBSTR(cod3dig,(i-1)*4,1) = "-" then highs_s[numranges] = INPUT(SUBSTR(cod3dig,((i-1)*4)+1,3),3.);
        else do;
          if highs_s[numranges] = 0 then highs_s[numranges] = lows_s[numranges];
          numranges = numranges + 1;
          lows_s[numranges] = INPUT(SUBSTR(cod3dig,((i-1)*4)+1,3),3.);
          end;
        end;
      end;
    /* set 4 digit values for ICD-8 or 9 */
    numvals = (len4dig+1) / 5;  /* integer division of 0420-0421,0429 - len = 14+1/5 = 3 - (5 is to account for the - or ,) */
    numranges = 1;
    do i = 1 to numvals;
      if i = 1 then lows_l[1] = INPUT(SUBSTR(cod4dig,1,4),4.);
      else do;
        if SUBSTR(cod4dig,(i-1)*5,1) = "-" then highs_l[numranges] = INPUT(SUBSTR(cod4dig,((i-1)*5)+1,4),4.);
        else do;
          if highs_l[numranges] = 0 then highs_l[numranges] = lows_l[numranges];
          numranges = numranges + 1;
          lows_l[numranges] = INPUT(SUBSTR(cod4dig,((i-1)*5)+1,4),4.);
          end;
        end;
      end;
    /* set 4 digit values for ICD-8 or 9 */
    end; /* codver = 8 or 9 */
  else do;  /* icd 10 */
    /* set 3 digit values for ICD-10 (char and 2 digits) */
    numvals = (len3dig+1) / 4;  /* integer division of D43-D44,D14-D21 - len = 15+1/4 = 4 - (4 is to account for the - or ,) */
    numranges = 1;
    do i = 1 to numvals;
      if i = 1 then do;
        chars_s[1] = SUBSTR(cod3dig,1,1);
        lows_s[1] = INPUT(SUBSTR(cod3dig,2,2),2.);
        end;
      else do;
        if SUBSTR(cod3dig,(i-1)*4,1) = "-" then do;
          highs_s[numranges] = INPUT(SUBSTR(cod3dig,((i-1)*4)+1+1,2),2.);
          end;
        else do;
          numranges = numranges + 1;
          chars_s[numranges] = SUBSTR(cod3dig,((i-1)*4)+1,1);
          lows_s[numranges] = INPUT(SUBSTR(cod3dig,((i-1)*4)+1+1,2),2.);
          end;
        end;
      end;
    /* set 4 digit values for ICD-10 - char and 3 digit */
    numvals = (len4dig+1) / 5;  /* integer division of C420-C421,D429 - len = 14+1/5 = 3 - (5 is to account for the - or ,) */
    numranges = 1;
    do i = 1 to numvals;
      if i = 1 then do;
        chars_l[1] = SUBSTR(cod4dig,1,1);
        lows_l[1] = INPUT(SUBSTR(cod4dig,2,3),3.);
        end;
      else do;
        if SUBSTR(cod4dig,(i-1)*5,1) = "-" then highs_l[numranges] = INPUT(SUBSTR(cod4dig,((i-1)*5)+1+1,3),3.);
        else do;
          numranges = numranges + 1;
          chars_l[numranges] = SUBSTR(cod4dig,((i-1)*5)+1,1);
          lows_l[numranges] = INPUT(SUBSTR(cod4dig,((i-1)*5)+1+1,3),3.);
          end;
        end;
      end;
    /* set 4 digit values for ICD-10 */
    end;
  do i = 1 to 30;
    if highs_s[i] = 0 then highs_s[i] = lows_s[i];
    if highs_l[i] = 0 then highs_l[i] = lows_l[i];
    end;
run;

/* split data into cases that have already been coded for cause-specific death classification above */
/* and those that require site-specific checks                                                      */
data sitecheck coded;
  set all;
  if seer_csdc = -1 then output sitecheck;
  else output coded;
run;

proc sort data = incods;
  by codver seqtype sitewho;
run;

proc sort data = sitecheck;
  by codver seqtype sitewho;
run;

/* if cause-specific death classification is not already set (non-site specific, or special) */
/* set based on COD and arrays setup above                                                   */
data sitecheck;
  merge sitecheck (in=incheck) incods;
  by codver seqtype sitewho;
  if incheck;
  array lows_s[30] low_s1-low_s30;
  array highs_s[30] high_s1-high_s30;
  array lows_l[30] low_l1-low_l30;
  array highs_l[30] high_l1-high_l30;
  array chars_s[30] $ char_s1-char_s30;
  array chars_l[30] $ char_l1-char_l30;
  seer_csdc = 0; /* initialize to dead of other causes */
  do i = 1 to 30;
    if codver in (8,9) then do;
      if (lows_s[i] <= cod89_3dig <= highs_s[i]) or (lows_l[i] <= cod89_4dig <= highs_l[i]) then seer_csdc = 1;
      end;
    else do; /* codver = 1 - ICD-10 */
      if ((chars_s[i] = cod10char and (lows_s[i] <= cod10_2dig <= highs_s[i])) or (chars_l[i] = cod10char and (lows_l[i] <= cod10_3dig <= highs_l[i]))) then seer_csdc = 1;
      end;   /* end codver = 1 */
    end;
run;

/* combine site specific and earlier coded cases and calculate the Other cause of death classification from Cause-specific */
data all;
  set sitecheck coded;
  if seer_csdc ^= 9 and (codver in (1, 8, 9) and (lengthn(cod_full) < 3 or cod_full in ('7777', '7797', '    '))) then seer_csdc = 8; /* missing/unknown COD */
  if seer_csdc in (8,9) then seer_othdc = seer_csdc; /* unknown/missing cod */
  else if codver = 0 then seer_othdc = 0;            /* alive - not event in either field */
  else if seer_csdc = 0 then seer_othdc = 1;         /* dead causes other than cancer */
  else seer_othdc = 0;                               /* dead cancer */
run;

data _null_;
  set all;
  file out lrecl=4048 pad;
  put @   1 buffer     $char4048.
      @2944 seer_csdc  1.
      @2945 seer_othdc 1.
      @; /* don't go to new line */
  if &ExcludeICDCodes = 1 then put @2940 '     '; /* icd code and cod version */
  else put; /* go to next line */
run;