DROP DATABASE IF EXISTS block;
CREATE DATABASE block;
USE block;

   /* USERS */
DROP TABLE IF EXISTS users;
CREATE TABLE users (
	id SERIAL PRIMARY KEY, 
    email VARCHAR(100) UNIQUE,
    password_hash varchar(100),
    is_deleted bit default 0,
    theme_id INT UNSIGNED DEFAULT 1, -- тема оформления приложения 
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

/* ГОСТ- овские Марки блоков */

DROP TABLE IF EXISTS block_marks;
CREATE TABLE block_marks (
 density INT UNIQUE,  -- плотность, от плотности зависит масса и вес
 name_mark VARCHAR(50) NOT NULL DEFAULT (CONCAT('D', density)),
 PRIMARY KEY (density)
);

/* Справочник стандартных блоков по умолчанию с вычитаемыми характеристиками. При добавлении блока, триггер дозаполнит таблицу*/
DROP TABLE IF EXISTS block_default;
CREATE TABLE block_default (
    id SERIAL PRIMARY KEY,
    length_block INT NOT NULL COMMENT 'Длина блока',  -- мм.
    height_block INT NOT NULL COMMENT 'Высота блока',  -- мм.
    width_block INT NOT NULL COMMENT 'Толщина блока',  -- мм.
    density_block INT NOT NULL COMMENT 'Плотность блока',  -- кг/м3 
    cost DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Стоимость блоков',
    unit_cost bit DEFAULT 0 COMMENT 'Ед. измерения 0 - за 1 м.куб. 1 - за 1 шт.',
    size_1_block DOUBLE  COMMENT 'Объём 1 блока, м3', 
     massa_1_block DOUBLE COMMENT 'Масса 1 блока',
    size_1_pallet DOUBLE DEFAULT 0.00 COMMENT 'Объем 1 паллета',
    massa_1_pallet DOUBLE COMMENT 'Масса 1 паллета',
    -- type_bl VARCHAR(50) NOT NULL COMMENT 'Назначение или тип блока',
    name_block VARCHAR(150) NOT NULL COMMENT 'Название блока',
	FOREIGN KEY (density_block) REFERENCES block_marks(density) ON UPDATE CASCADE ON DELETE CASCADE  -- каскадно удаляется/обновляется <- block_marks(density)
	-- FOREIGN KEY (id) REFERENCES block_marks(id) ON UPDATE CASCADE ON DELETE CASCADE  -- каскадно удаляется/обновляется <- block_marks(density)
);

/*При добавлении блока, триггер дозаполнит таблицу*/
DROP TRIGGER IF EXISTS tg_insert_block_default;
DELIMITER //
CREATE TRIGGER tg_insert_block_default BEFORE INSERT ON block_default
FOR EACH ROW
BEGIN 
	SET NEW.size_1_block = NEW.length_block * NEW.height_block * NEW.width_block / 1000000000;  -- Объём 1 блока, м3
    SET NEW.massa_1_block = NEW.size_1_block  * NEW.density_block;  -- Масса 1 блока = Объем * Плотность
    SET NEW.massa_1_pallet = NEW.size_1_pallet / NEW.size_1_block * NEW.massa_1_block;  -- Масса 1 паллета = Объем 1 паллета / Объём 1 блока, м3 * Масса 1 блока
    SET NEW.name_block = CONCAT('D', NEW.density_block, ' ', NEW.length_block, '*', NEW.height_block, '*', NEW.width_block);  -- Составное имя блока
END//
DELIMITER ;

/*При обновлении данных триггер все проверит*/
DROP TRIGGER IF EXISTS tg_update_block_default;
DELIMITER //
CREATE TRIGGER tg_update_block_default BEFORE UPDATE ON block_default
FOR EACH ROW
BEGIN 
	SET NEW.size_1_block = NEW.length_block * NEW.height_block * NEW.width_block / 1000000000;  -- Объём 1 блока, м3
    SET NEW.massa_1_block = NEW.size_1_block  * NEW.density_block;  -- Масса 1 блока = Объем * Плотность
    SET NEW.massa_1_pallet = NEW.size_1_pallet / NEW.size_1_block * NEW.massa_1_block;  -- Масса 1 паллета = Объем 1 паллета / Объём 1 блока, м3 * Масса 1 блока
    SET NEW.name_block = CONCAT('D', NEW.density_block, ' ', NEW.length_block, '*', NEW.height_block, '*', NEW.width_block);  -- Составное имя блока
END//
DELIMITER ;

/* Пользовательские блоки */
DROP TABLE IF EXISTS block_user;
CREATE TABLE block_user (
--  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE,
    id SERIAL PRIMARY KEY,
    user_id BIGINT UNSIGNED,
    length_block_u INT NOT NULL COMMENT 'Длина блока',  -- мм.
    height_block_u INT NOT NULL COMMENT 'Высота блока',  -- мм.
    width_block_u INT NOT NULL COMMENT 'Толщина блока',  -- мм. толщина блока определяет толщену стены по умолчанию в расчете
    density_block_u INT DEFAULT NULL COMMENT 'Плотность блока',  -- кг/м3 
    cost_u DECIMAL(10,2) DEFAULT NULL COMMENT 'Стоимость блоков', 
    unit_cost_u bit DEFAULT 0 COMMENT 'Ед. измерения 0 - м.куб. 1 - шт.',
    size_1_block_u DOUBLE COMMENT 'Объём 1 блока, м3',
    massa_1_block_u DOUBLE DEFAULT NULL COMMENT 'Масса 1 блока',
    size_1_pallet_u DOUBLE DEFAULT NULL COMMENT 'Объем 1 паллета',
    massa_1_pallet_u DOUBLE DEFAULT NULL COMMENT 'Масса 1 паллета',
    name_block_u VARCHAR(150) DEFAULT NULL,
-- PRIMARY KEY (id, user_id),
	FOREIGN KEY (density_block_u) REFERENCES block_marks(density) ON UPDATE CASCADE ON DELETE CASCADE,  -- каскадно удаляется/обновляется <- block_marks(density)
	-- FOREIGN KEY (id) REFERENCES block_marks(id) ON UPDATE CASCADE ON DELETE CASCADE,  -- каскадно удаляется/обновляется <- block_marks(density)
	FOREIGN KEY (user_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE CASCADE  -- каскадно удаляется/обновляется <- users(id)
);
/* Триггер на добавление */
DROP TRIGGER IF EXISTS tg_insert_block_user;
DELIMITER //
CREATE TRIGGER tg_insert_block_user BEFORE INSERT ON block_user
FOR EACH ROW
BEGIN 
	SET @nm_block := '';  -- Переменная является частью названия блока по умолчанию
	SET @var_size_block := NEW.length_block_u * NEW.height_block_u * NEW.width_block_u / 1000000000;   -- Объём 1 блока, м3
	SET NEW.size_1_block_u = @var_size_block;
	
	IF NEW.density_block_u IS NOT NULL THEN  -- Если известна плотность
		SET @nm_block = CONCAT('D', NEW.density_block_u, ' ');  -- Добавляем ее в название блока
		SET NEW.massa_1_block_u = NEW.size_1_block_u  * NEW.density_block_u;  -- Расчитаем Массу 1 блока = Объем * Плотность
	END IF;

	IF (NEW.size_1_pallet_u IS NOT NULL) OR (NEW.massa_1_block_u IS NOT NULL)  THEN  -- Если известны объем 1 паллеты И масса 1 блока
	  	SET NEW.massa_1_pallet_u = NEW.size_1_pallet_u / NEW.size_1_block_u * NEW.massa_1_block_u;  -- Масса 1 паллеты = Объем 1 паллеты / Объём 1 блока, м3 * Масса 1 блока
	 END IF;
	
	IF NEW.name_block_u IS NULL THEN  -- Если пользователь не задал название своего блока
		SET NEW.name_block_u = CONCAT(@nm_block, NEW.length_block_u, '*', NEW.height_block_u, '*', NEW.width_block_u);  -- мы сформируем название сами, используя переменную @nm_block
    END IF;
   
   	IF (NEW.cost_u IS NOT NULL) AND (NEW.unit_cost_u IS NULL)  THEN  -- Если пользователь указал цену, но не указа ед.измер (за куб '0' или шт. '1')
	  	SET NEW.unit_cost_u = 0;  -- установим ед. изм. за куб - '0'
	 END IF;
END//
DELIMITER ;

/* Триггер на обновление */
DROP TRIGGER IF EXISTS tg_update_block_user;
DELIMITER //
CREATE TRIGGER tg_update_block_user BEFORE UPDATE ON block_user
FOR EACH ROW
BEGIN 
	SET @nm_block := '';  -- Переменная является частью названия блока по умолчанию
	SET @var_size_block := NEW.length_block_u * NEW.height_block_u * NEW.width_block_u / 1000000000;   -- Объём 1 блока, м3
	SET NEW.size_1_block_u = @var_size_block;
	
	IF NEW.density_block_u IS NOT NULL THEN  -- Если известна плотность
		SET @nm_block = CONCAT('D', NEW.density_block_u, ' ');  -- Добавляем ее в название блока
		SET NEW.massa_1_block_u = NEW.size_1_block_u  * NEW.density_block_u;  -- Расчитаем Массу 1 блока = Объем * Плотность
	END IF;

	IF (NEW.size_1_pallet_u IS NOT NULL) OR (NEW.massa_1_block_u IS NOT NULL)  THEN  -- Если известны объем 1 паллеты И масса 1 блока
	  	SET NEW.massa_1_pallet_u = NEW.size_1_pallet_u / NEW.size_1_block_u * NEW.massa_1_block_u;  -- Масса 1 паллеты = Объем 1 паллеты / Объём 1 блока, м3 * Масса 1 блока
	 END IF;
	
	IF NEW.name_block_u IS NULL OR  NEW.name_block_u = '' OR  NEW.name_block_u = OLD.name_block_u  THEN  -- Если пользователь не задал название своего блока
		SET NEW.name_block_u = CONCAT(@nm_block, NEW.length_block_u, '*', NEW.height_block_u, '*', NEW.width_block_u);  -- мы сформируем название сами, используя переменную @nm_block
    END IF;
   
   	IF (NEW.cost_u IS NOT NULL) AND (NEW.unit_cost_u IS NULL)  THEN  -- Если пользователь указал цену, но не указа ед.измер (за куб '0' или шт. '1')
	  	SET NEW.unit_cost_u = 0;  -- установим ед. изм. за куб - '0'
	 END IF;
END//
DELIMITER ;

/* Стены и перегородки юзеров */
DROP TABLE IF EXISTS wall_user;
CREATE TABLE wall_user (
--  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE,
    id SERIAL PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
  	created_at DATETIME DEFAULT NOW(),
    -- Размеры стены:
    length_wall DOUBLE NOT NULL,  -- м.
    height_wall DOUBLE NOT NULL,  -- м.
    width_wall DOUBLE NOT NULL COMMENT 'Толщина стены',  -- м.
    -- Размеры проемов:
    windows_number INT DEFAULT 0 COMMENT 'Количество окон',
    windows_width DOUBLE DEFAULT 0 COMMENT 'Ширина окна',  -- м.
    windows_height DOUBLE DEFAULT 0 COMMENT 'Высота окна',  -- м.
    doors_number  INT DEFAULT 0 COMMENT 'Двери',
    doors_width DOUBLE DEFAULT 0 COMMENT 'Ширина двери',   -- м.
    doors_height DOUBLE DEFAULT 0 COMMENT 'Высота двери',   -- м.
    size_wall DOUBLE DEFAULT NULL COMMENT 'Объём стены',  -- Расчитаем объем проема с учетом имеющихся проемов
    name_wall VARCHAR(150) DEFAULT NULL,  -- Нзвание стены
    -- PRIMARY KEY (id, user_id),
	FOREIGN KEY (user_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE CASCADE);  -- каскадно удаляется/обновляется <- users(id)

/* Триггер обработает не заполненные данные и дозаполнит поля */
DROP TRIGGER IF EXISTS tg_insert_wall_user;
DELIMITER //
CREATE TRIGGER tg_insert_wall_user BEFORE INSERT ON wall_user
FOR EACH ROW
BEGIN
    -- SET NEW.created_at = NOW()
	SET NEW.created_at = NOW() - INTERVAL FLOOR(RAND() * 1100) DAY; -- случайные даты за последние 3 года
	IF NEW.name_wall  IS NULL THEN SET NEW.name_wall = CONCAT('Стена ', NEW.length_wall, '*', NEW.height_wall, '*', NEW.width_wall); -- название стены 
	END IF;
	IF NEW.doors_number IS NULL THEN SET NEW.doors_number = 0; 
	END IF;
	IF NEW.doors_width IS NULL THEN SET NEW.doors_width = 0; 
	END IF;
	IF NEW.doors_height IS NULL THEN SET NEW.doors_height = 0; 
	END IF;
	IF NEW.windows_number IS NULL THEN SET NEW.windows_number = 0; 
	END IF;
	IF NEW.windows_width IS NULL THEN SET NEW.windows_width = 0; 
	END IF;
	IF NEW.windows_height IS NULL THEN SET NEW.windows_height = 0; 
	END IF;
    SET @area_of_openings :=  (NEW.windows_height * NEW.windows_number * NEW.windows_width + NEW.doors_number * NEW.doors_width * NEW.doors_height); -- площадь проемов
	SET @area_of_wall := NEW.length_wall * NEW.height_wall - @area_of_openings; -- площадь стены
    SET NEW.size_wall = (@area_of_wall * NEW.width_wall);  -- объем стены
END// 
DELIMITER ;

/*При обновлении аналогично*/
DROP TRIGGER IF EXISTS tg_update_wall_user;
DELIMITER //
CREATE TRIGGER tg_update_wall_user BEFORE UPDATE ON wall_user
FOR EACH ROW
BEGIN
--  SET NEW.created_at = NOW(); 
	SET NEW.created_at = NOW() - INTERVAL FLOOR(RAND() * 1100) DAY; -- случайные даты за последние 3 года
	IF NEW.name_wall  = OLD.name_wall OR 
		NEW.name_wall IS NULL OR 
		NEW.name_wall ='' THEN 
		SET NEW.name_wall = CONCAT('Стена ', NEW.length_wall, '*', NEW.height_wall, '*', NEW.width_wall); -- обновляем название стены 
	END IF;
	IF NEW.doors_number IS NULL THEN SET NEW.doors_number = 0; 
	END IF;
	IF NEW.doors_width IS NULL THEN SET NEW.doors_width = 0; 
	END IF;
	IF NEW.doors_height IS NULL THEN SET NEW.doors_height = 0; 
	END IF;
	IF NEW.windows_number IS NULL THEN SET NEW.windows_number = 0; 
	END IF;
	IF NEW.windows_width IS NULL THEN SET NEW.windows_width = 0; 
	END IF;
	IF NEW.windows_height IS NULL THEN SET NEW.windows_height = 0; 
	END IF;
    SET @area_of_openings :=  (NEW.windows_height * NEW.windows_number * NEW.windows_width + NEW.doors_number * NEW.doors_width * NEW.doors_height); -- площадь проемов
	SET @area_of_wall := NEW.length_wall * NEW.height_wall - @area_of_openings; -- площадь стены
    SET NEW.size_wall = (@area_of_wall * NEW.width_wall);  -- объем стены
END// 
DELIMITER ;

/* Ниже три таблицы - части одного сохраненного расчета 
*Это таблица является, частью основного расчета и содержит первичные данные полученные от пользователя на прямую (через поля ввода приложения), 
 * либо из таблиц с пользовательскими блоками, справочника блоков по умолчанию, или пользовательскими стенами.
 * 
 * - Таблица не может быть связана с таблицами справочниками блоков и стен, так как источники могут быть разными
 *  - Не должна удаляться или обновляться при изменении свойств блокав и стен в справочых таблицах
 *  - Связана только с пользователем
 */

-- В расчете учитывалось
DROP TABLE IF EXISTS save_rezult_data;
CREATE TABLE save_rezult_data (
    id SERIAL PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL, 
    name_block VARCHAR(150) NOT NULL COMMENT 'Название блока',
    name_wall VARCHAR(150) DEFAULT NULL COMMENT 'Нзвание стены', 
    windows_number INT DEFAULT 0 COMMENT 'Количество окон',
    windows_width DOUBLE DEFAULT 0 COMMENT 'Ширина окна',  -- м.
    windows_height DOUBLE DEFAULT 0 COMMENT 'Высота окна',  -- м.
    doors_number  INT DEFAULT 0 COMMENT 'Двери',
    doors_width DOUBLE DEFAULT 0 COMMENT 'Ширина двери',   -- м.
    doors_height DOUBLE DEFAULT 0 COMMENT 'Высота двери',   -- м.
	FOREIGN KEY (user_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE CASCADE  -- каскадно удаляется/обновляется <- users(id)
);

-- Основной расчет
DROP TABLE IF EXISTS save_rezult;
CREATE TABLE save_rezult (
    id SERIAL PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL, 
   	type_result_r CHAR(1) COMMENT 'Флаг основного расчета',
    -- Минимально-гарантированный результат
    number_of_blocks INT DEFAULT NULL COMMENT 'Количество блоков', 
    total_block_size INT DEFAULT NULL COMMENT 'Объем блоков',  
    -- Если известен объем 1 паллеты
    size_1_pallet DOUBLE DEFAULT NULL COMMENT 'Объем 1 паллета',
    total_pallet DOUBLE DEFAULT NULL COMMENT 'Количество паллет', 
    -- Если известна масса 1 блока или плотность (марка) 
    massa_1_block DOUBLE DEFAULT NULL COMMENT 'Масса 1 блока',
    massa_1_pallet DOUBLE DEFAULT NULL COMMENT 'Масса 1 паллета',
    massa_total DOUBLE DEFAULT NULL COMMENT 'Общая масса блоков',
    cost_total DECIMAL(10,2) DEFAULT NULL COMMENT 'Общая стоимость',
   --  Альтернативный расчет
   	type_result_a CHAR(1) COMMENT 'Флаг альтернативного расчета',
    number_of_blocks_a INT DEFAULT NULL COMMENT 'Количество блоков',  
    total_block_size_a INT DEFAULT NULL COMMENT 'Объем блоков',  
    total_pallet_a DOUBLE DEFAULT NULL COMMENT 'Количество паллет', 
    massa_total_a DOUBLE DEFAULT NULL COMMENT 'Общая масса блоков',
    cost_total_a DECIMAL(10,2) DEFAULT NULL COMMENT 'Общая стоимость',
    FOREIGN KEY (id) REFERENCES save_rezult_data(id) ON UPDATE CASCADE ON DELETE CASCADE);
   -- END SAVE
