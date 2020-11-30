USE block;

DROP PROCEDURE IF EXISTS pr_raschet_save_default_block;
DELIMITER //

/* 
 * Данная процедура запускает расчет блоков, в результате формируются временные таблицы с результатом расчета (таблицы связаны между собой, являются одной сущностью).  
 * Временные таблицы имитируют вывод результата на экран устройства пользователя, нам нет смысла записывать все расчеты в базу!
 * Временные а не постоянные таблицы нужны, что бы обработать результат, показать его пользователю, и только если пользователь явно указал, что результат нужно сохранить, 
 * данные из временнных таблиц будут записаны в постоянные.  За сохранение отвечает параметр процедуры marker_save 0 или 1.
*/

-- Считаем дефолтные блоки и стены пользователя:
CREATE PROCEDURE pr_raschet_save_default_block (IN u_i INT, IN bl_i INT, IN w_i INT, IN marker_save BIT)
BEGIN
	SET @us_id = u_i;  -- user id
	SET @block_id = bl_i; -- id блока default
	SET @wall_id = w_i;  -- id стены пользователя
	SET @save = marker_save; -- если 1, запустится сохранение таблиц из временных во внутренни
	
/*  Временная таблица №1 - содержит исходные данные расчета, что с чем считали */
	DROP TEMPORARY TABLE IF EXISTS tmp_data_table;
	CREATE TEMPORARY TABLE tmp_data_table
		SELECT 
		NULL AS Id,
		@us_id AS user_id,
	    bd.name_block , 
	    wu.name_wall ,
	    wu.windows_number ,
	    wu.windows_width ,
	    wu.windows_height ,
	    wu.doors_number ,
	    wu.doors_width ,
	    wu.doors_height 
		FROM 
			block_default bd
	   LEFT JOIN 
		    wall_user wu
		ON wu.id = @wall_id
		WHERE bd.id = @block_id;
	
/*  Временная таблица №2 - содержит результаты основного расчтета */
	DROP TEMPORARY TABLE IF EXISTS tmp_table;
	CREATE TEMPORARY TABLE tmp_table
		SELECT 
		NULL AS Id,
		  @us_id AS user_id,
		  'R' AS type_result_r,
		  wu.size_wall / bd.size_1_block AS number_of_blocks,  -- Необходимое число блоков
		  wu.size_wall AS total_block_size,  -- Объем блоков
		  bd.size_1_pallet,  -- Объем 1 паллеты
		  wu.size_wall / bd.size_1_pallet AS total_pallet,   -- Количество паллет
		  bd.massa_1_block,  -- Масса 1 блока
		  bd.massa_1_pallet,   -- Масса 1 палетты
		  (wu.size_wall / bd.size_1_block) * bd.massa_1_block AS massa_total,   -- Масса всех блоков
		  IF (bd.unit_cost = 0,  bd.cost *  wu.size_wall, bd.cost * (wu.size_wall / bd.size_1_block)) AS cost_total,   -- Считаем стоимость учитывая флаг unit_cost (ед.измерения)
		  'A' AS type_result_a,
		  bd.size_1_pallet * CEIL (wu.size_wall / bd.size_1_pallet) / bd.size_1_block AS number_of_blocks_a,  -- Необходимое число блоков   	
		  bd.size_1_pallet * CEIL (wu.size_wall / bd.size_1_pallet) AS total_block_size_a,   -- Объем блоков
		  CEIL(wu.size_wall / bd.size_1_pallet) AS total_pallet_a,   -- Количество паллет
		 (bd.size_1_pallet * CEIL(wu.size_wall / bd.size_1_pallet) / bd.size_1_block) * bd.massa_1_block AS massa_total_a,   -- Масса всех блоков
   		 IF (bd.unit_cost = 0,   -- Считаем стоимость учитывая флаг unit_cost (ед.измерения)
   		 bd.cost * bd.size_1_pallet * CEIL (wu.size_wall / bd.size_1_pallet), 
   		 bd.cost * (bd.size_1_pallet * CEIL(wu.size_wall / bd.size_1_pallet) / bd.size_1_block)) AS cost_total_a
		FROM 
			block_default bd
	   LEFT JOIN 
		    wall_user wu
		ON wu.id = @wall_id
		WHERE bd.id = @block_id;
	
	 -- Если пользователь хочет сохранить (marker_save = 1) - сохраняем!
		IF@save = 1 THEN
			START TRANSACTION;
			INSERT INTO `save_rezult_data` SELECT * FROM `tmp_data_table`;
			INSERT INTO `save_rezult` SELECT * FROM `tmp_table`;
			COMMIT;
		END IF;
	    SELECT * FROM vw_saves WHERE user_id = @us_id;
	END//
DELIMITER ;

/* Процедура аналогична pr_raschet_save_default_block, с той разницей, что изменился один из источников данных (блоки пользователя). 
* Необходимо реализовать функцию подстановки источника, что бы не создавать схожие  процедуры
*/

-- Процедура расчета: Блоки пользователя  -- Стены пользователя
DROP PROCEDURE IF EXISTS pr_raschet_save_user_block;
DELIMITER //

CREATE PROCEDURE pr_raschet_save_user_block (IN ui INT, IN blk INT, IN wi INT, IN ms BIT)
BEGIN
	SET @us= ui;  -- user id
	SET @bl = blk; -- id блока пользователя
	SET @wl = wi;  -- id стены пользователя
	SET @sv = ms; -- если 1, запустится сохранение таблиц из временных во внутренни
	
	DROP TEMPORARY TABLE IF EXISTS tmp_data_table;
	CREATE TEMPORARY TABLE tmp_data_table
		SELECT 
		NULL AS Id,
		@us AS user_id,
	    bu.name_block_u , 
	    wu.name_wall ,
	    wu.windows_number ,
	    wu.windows_width ,
	    wu.windows_height ,
	    wu.doors_number ,
	    wu.doors_width ,
	    wu.doors_height 
		FROM 
			block_user bu
	   LEFT JOIN 
		    wall_user wu
		ON wu.id = @wl
		WHERE bu.id = @bl;
	
/*  Временная таблица №2 - содержит результаты основного расчтета */
	DROP TEMPORARY TABLE IF EXISTS tmp_table;
	CREATE TEMPORARY TABLE tmp_table
		SELECT 
		NULL AS Id,
		  @us AS user_id,
		  'R' AS type_result_r,
		  wu.size_wall / bu.size_1_block_u AS number_of_blocks,  -- Необходимое число блоков
		  wu.size_wall AS total_block_size,  -- Объем блоков
		  bu.size_1_pallet_u ,  -- Объем 1 паллеты 
		  wu.size_wall / bu.size_1_pallet_u AS total_pallet,   -- Количество паллет
		  bu.massa_1_block_u ,  -- Масса 1 блока
		  bu.massa_1_pallet_u ,   -- Масса 1 палетты
		  (wu.size_wall / bu.size_1_block_u) * bu.massa_1_block_u AS massa_total,   -- Масса всех блоков
		  IF (bu.unit_cost_u = 0,  bu.cost_u *  wu.size_wall, bu.cost_u * (wu.size_wall / bu.size_1_block_u)) AS cost_total,   -- Считаем стоимость учитывая флаг unit_cost (ед.измерения)
		  'A' AS type_result_a,
		  bu.size_1_pallet_u * CEIL (wu.size_wall / bu.size_1_pallet_u) / bu.size_1_block_u AS number_of_blocks_a,  -- Необходимое число блоков   	
		  bu.size_1_pallet_u * CEIL (wu.size_wall / bu.size_1_pallet_u) AS total_block_size_a,   -- Объем блоков
		  CEIL(wu.size_wall / bu.size_1_pallet_u) AS total_pallet_a,   -- Количество паллет
		 (bu.size_1_pallet_u * CEIL(wu.size_wall / bu.size_1_pallet_u) / bu.size_1_block_u) * bu.massa_1_block_u AS massa_total_a,   -- Масса всех блоков
   		 IF (bu.unit_cost_u = 0,   -- Считаем стоимость учитывая флаг unit_cost (ед.измерения)
   		 bu.cost_u * bu.size_1_pallet_u * CEIL (wu.size_wall / bu.size_1_pallet_u), 
   		 bu.cost_u * (bu.size_1_pallet_u * CEIL(wu.size_wall / bu.size_1_pallet_u) / bu.size_1_block_u)) AS cost_total_a
		FROM 
			block_user bu
	   LEFT JOIN 
		    wall_user wu
		ON wu.id = @wl
		WHERE bu.id = @bl;
	
	 -- Если пользователь хочет сохранить (ms = 1) - сохраняем!
	IF@sv = 1 THEN
			START TRANSACTION;
			INSERT INTO `save_rezult_data` SELECT * FROM `tmp_data_table`;
			INSERT INTO `save_rezult` SELECT * FROM `tmp_table`;
			COMMIT;
		END IF;
	SELECT * FROM vw_saves WHERE user_id = @us;
	END//
DELIMITER ;

/*
 * Процедура расчитывает смету до 4-ых сохраненных расчетов (до 4 стен)
 * Параметры: user id / id расчета 1 / id расчета 2/ id расчета 3 / id расчета 4
 */

DROP PROCEDURE IF EXISTS pr_smeta;
DELIMITER //
CREATE PROCEDURE pr_smeta (IN var_id INT, IN var_block_id_1 INT, IN var_block_id_2 INT, IN var_block_id_3 INT, IN var_block_id_4 INT)
BEGIN
	DECLARE vi INT DEFAULT 0;
	SET @us_i = var_id;  -- user id
	SET @save1 = var_block_id_1;  -- сохраненный расчет 1
	SET @save2 = var_block_id_2;  -- сохраненный расчет 2
	SET @save3 = var_block_id_3;  -- сохраненный расчет 3
	SET @save4 = var_block_id_4;  -- сохраненный расчет 4
	
	SELECT 
	user_id,
	sum(number_of_blocks) AS  count_blocks, 
	sum(total_block_size) AS size_m3, 
	sum(massa_total) AS massa,
	sum(cost_total) AS cost
	from vw_saves where user_id = @us_i AND save_id IN (@save1, @save2, @save3, @save4) GROUP BY user_id ;
	
	SET @save1 = NULL;
	SET @save2 = NULL;
	SET @save3 = NULL; 
	SET @save4 = NULL;
END//
DELIMITER ;

-- ПРЕДСТАВЛЕНИЕ  расчетов, которые пользователи сохранили
DROP VIEW IF EXISTS  vw_saves;
CREATE VIEW  vw_saves  AS 
(SELECT srd.id AS save_id, srd.user_id, sr.type_result_r AS `type`, 
sr.number_of_blocks, sr.total_block_size, sr.size_1_pallet, sr.total_pallet, sr.massa_1_block, sr.massa_1_pallet, sr.massa_total, sr.cost_total, srd.name_block, srd.name_wall 
FROM save_rezult sr
LEFT JOIN save_rezult_data srd ON sr.id = srd.id)
UNION 
(SELECT srd.id AS save_id, srd.user_id, sr.type_result_a AS `type`,
sr.number_of_blocks_a, sr.total_block_size, sr.size_1_pallet, sr.total_pallet_a , sr.massa_1_block, sr.massa_1_pallet, sr.massa_total_a , sr.cost_total_a , srd.name_block, srd.name_wall 
FROM save_rezult sr
LEFT JOIN save_rezult_data srd ON sr.id = srd.id) ORDER BY save_id ;


-- ПРЕДСТАВЛЕНИЕ  TOP - 5 самых активных пользователей, первый тот кто больше потратил денег в расчетах
DROP VIEW IF EXISTS  vw_top5_users;
CREATE VIEW  vw_top5_users  AS 
SELECT 
u.email AS login,  -- login user
srd.user_id,  -- user id
count(srd.id)  AS save,   -- количество сохраненных расчетов
SUM(sr.number_of_blocks) AS blocks_count,   -- сумма блоков в сохраненных расчетах
SUM(sr.cost_total) AS money  -- сумма стоимости всех блоков
FROM save_rezult_data srd  
JOIN users u on (u.id = srd.user_id) 
JOIN save_rezult sr on (sr.id = srd.id) GROUP BY srd.user_id ORDER BY money DESC LIMIT 5; 