delimiter $$

CREATE PROCEDURE ParseXml(in xml_input TEXT)
COMMENT 'Popis...'
BEGIN
  DECLARE Iterator INT UNSIGNED DEFAULT 14;
  DECLARE Jterator INT UNSIGNED DEFAULT 0;
  DECLARE Kterator INT UNSIGNED DEFAULT 0;
  DECLARE StranaCount INT UNSIGNED;
  DECLARE KrajPath TEXT;
  DECLARE StranaPath TEXT;
  DECLARE CRPath TEXT;
  DECLARE MandatoveCislo Real;
  DECLARE ZbytkoveMandaty Int;
  DECLARE KrajskeMandaty Int;



  CREATE TEMPORARY TABLE RawKraj (Kraj_ID Int UNSIGNED, Hlasy Int, Mandaty Int DEFAULT 0, Zbytek Decimal(5,2));

  CREATE TEMPORARY TABLE RawStranaKraj (RawStranaKraj_ID Int, Kraj_ID Int, Strana_ID Int, Hlasy Int, Mandaty Int);

  CREATE TEMPORARY TABLE RawCR (Strana_ID Int UNSIGNED, Hlasy Int, Procent DECIMAL(5,2));

  CREATE TEMPORARY TABLE RawKrajAux (Kraj_ID Int UNSIGNED);
  CREATE TEMPORARY TABLE RawMandatyHlasy (Kraj_ID Int UNSIGNED, Strana_ID Int, Mandaty Int, Podil Real);



  -- přes kraje
  WHILE Iterator > 0 DO        
    
    SET KrajPath := concat('//VYSLEDKY/KRAJ[', Iterator, ']');

    INSERT INTO RawKraj VALUES (
      extractValue(xml_input, concat(KrajPath,'/@CIS_KRAJ')),
      extractValue(xml_input, concat(KrajPath,'/UCAST/@PLATNE_HLASY')),
      0,
0
    );

    SET Jterator := extractValue(xml_input,concat('count(',KrajPath,'/STRANA)'));
    
    WHILE Jterator > 0  DO --  StranaCount DO        
      SET StranaPath := concat(KrajPath, '/STRANA[', Jterator, ']');

      INSERT INTO RawStranaKraj VALUES (
        extractValue(xml_input, concat(KrajPath,'/@CIS_KRAJ'))*1000 + Jterator,
        extractValue(xml_input, concat(KrajPath,'/@CIS_KRAJ')),
        extractValue(xml_input, concat(StranaPath,'/@KSTRANA')),
        extractValue(xml_input, concat(StranaPath,'/HODNOTY_STRANA/@HLASY')),
        0     
  );

       SET Jterator := Jterator - 1;
    END WHILE;
       
    SET Iterator := Iterator - 1;    
  END WHILE;

  SET Iterator := extractValue(xml_input,'count(//VYSLEDKY/CR/STRANA)');
  WHILE Iterator > 0 DO        
    SET CRPath := concat('//VYSLEDKY/CR/STRANA[', Iterator, ']');

     INSERT INTO RawCR VALUES (
      
      extractValue(xml_input, concat(CRPath,'/@KSTRANA')),
      extractValue(xml_input, concat(CRPath,'/HODNOTY_STRANA/@HLASY')),
      extractValue(xml_input, concat(CRPath,'/HODNOTY_STRANA/@PROC_HLASU'))
    );
    SET Iterator := Iterator - 1;
  END WHILE;
  


  SET MandatoveCislo := extractValue(xml_input, '//VYSLEDKY/CR/UCAST/@PLATNE_HLASY')/200;

  UPDATE 
    RawKraj
  SET 
    Mandaty=FLOOR(Hlasy/MandatoveCislo),
    Zbytek=(Hlasy/MandatoveCislo)-FLOOR(Hlasy/MandatoveCislo);
  



  SELECT @ZbytkoveMandaty := 200 - T.ZbytkoveMandaty FROM (
    SELECT SUM(Mandaty) AS ZbytkoveMandaty
    FROM RawKraj
  ) AS T;

  SET ZbytkoveMandaty :=  @ZbytkoveMandaty;
 

-- SET ZbytkoveMandaty :=  6;

  INSERT INTO RawKrajAux
  SELECT Kraj_ID FROM RawKraj ORDER BY Zbytek DESC LIMIT ZbytkoveMandaty ;

  UPDATE
    RawKraj AS RK
    JOIN RawKrajAux AS RKA USING (Kraj_ID)
  SET 
    RK.Mandaty = RK.Mandaty + 1;




  SET Iterator := 14;
  WHILE Iterator > 0 DO        
    SELECT @KrajskeMandaty := RK.Mandaty FROM RawKraj RK WHERE RK.Kraj_ID = Iterator;
 --   SET @KrajskeMandaty := 8;
   
    SET Jterator := @KrajskeMandaty;
    WHILE Jterator > 0 DO
      
      SELECT @StranaCount := T.StranaCount FROM (SELECT COUNT(1) AS StranaCount FROM RawStranaKraj WHERE Kraj_ID = Iterator) AS T;
  --    SET @StranaCount = 18;
      SET Kterator := @StranaCount;
      WHILE Kterator > 0 DO
        INSERT INTO RawMandatyHlasy
        SELECT
          Iterator,
          RS.Strana_ID,
          Jterator,
          IF((IFNULL(Jterator,0) > 0) AND (RCR.Procent > 5), RS.Hlasy/Jterator, 0)
        FROM
          RawStranaKraj RS
          JOIN RawCR RCR USING(Strana_ID)
        WHERE
          RS.RawStranaKraj_ID = 1000*Iterator + Kterator; 
   
        SET Kterator := Kterator - 1;
      END WHILE; 
      
      SET Jterator := Jterator - 1;
    END WHILE;       

    SET Iterator := Iterator - 1;
  END WHILE;

  SET Iterator := 14;

  WHILE Iterator > 0 DO
 

    SET Iterator := Iterator - 1;

  END WHILE;



   SET Iterator := 14;
   WHILE Iterator > 0 DO        
    SELECT @KrajskeMandaty := RK.Mandaty FROM RawKraj RK WHERE RK.Kraj_ID = Iterator;
 --   SET @KrajskeMandaty := 8;
   
  --  SET Jterator := @KrajskeMandaty;
   -- WHILE Jterator > 0 DO
    
    SET KrajskeMandaty := @KrajskeMandaty;
    UPDATE
      RawStranaKraj RS
    JOIN (
      select
        T.Strana_ID, count(T.Strana_ID) AS Mandaty
      from (
        select Strana_ID from RawMandatyHlasy
        where Kraj_ID = Iterator
        order by Kraj_ID, Podil DESC
        limit KrajskeMandaty
     ) AS T
     group by T.Strana_ID
    ) AS NRS USING(Strana_ID)
    SET
      RS.Mandaty = NRS.Mandaty
    WHERE RS.Kraj_ID = Iterator;

      
 --     SET Jterator := Jterator - 1;
  --  END WHILE;       

    SET Iterator := Iterator - 1;
  END WHILE;


    
  UPDATE 
    Kraje K 
    JOIN (SELECT RS.Kraj_ID, SUM(Mandaty) AS Mandaty, round(SUM(Hlasy)/SUM(Mandaty)) AS HlasuNaMandat FROM RawStranaKraj RS Where RS.Mandaty > 0 GROUP BY RS.Kraj_ID) AS RK USING(Kraj_ID)
  SET
    K.Mandaty = RK.Mandaty,
    K.HlasuNaMandat = RK.HlasuNaMandat;


  TRUNCATE StranyKraje;
  
  INSERT INTO
    StranyKraje (Strana_ID, Kraj_ID, Mandaty, Hlasy)
  SELECT RS.Strana_ID, RS.Kraj_ID, SUM(Mandaty) AS Mandaty, SUM(Hlasy) AS Hlasy FROM RawStranaKraj RS GROUP BY RS.Kraj_ID, RS.Strana_ID;  
  
  CALL MarkElectedCandidates();

END$$

delimiter ;
