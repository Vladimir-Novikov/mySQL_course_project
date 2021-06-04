/* База данных "Интернет-магазин электрического оборудования"
 * Содержит информацию о покупателях, товарах и ценах.
 * Также хранит информацию о размере скидки каждого покупателя, налоговой ставке, и сохраняет историю цен на каждый товар.
 * Решает задачи: вывод информации в виде каталога (товар - цена), вывод состава заказа, расчет стоимости заказа (со скидкой, без скидки, до налогов).
 * И выполняет задачу хранения истории цен.
 */

DROP DATABASE IF EXISTS el_shop;
CREATE DATABASE el_shop;
USE el_shop;

DROP TABLE IF EXISTS discount;
CREATE TABLE discount( 
  id SERIAL PRIMARY KEY,
  discount INT UNSIGNED 
)COMMENT 'Размер скидки';

DROP TABLE IF EXISTS users;
CREATE TABLE users(
	id SERIAL PRIMARY KEY,
	firstname VARCHAR(255),
	lastname VARCHAR(255),
	phone BIGINT UNIQUE,
	email VARCHAR(255) UNIQUE
)COMMENT 'Пользователи';

DROP TABLE IF EXISTS payment_type;
CREATE TABLE payment_type(
  id SERIAL PRIMARY KEY,
  payment VARCHAR(255) UNIQUE
)COMMENT 'Тип платежа';

DROP TABLE IF EXISTS user_orders;
CREATE TABLE user_orders( -- кто заказал / номер заказа    получается история заказов
	id SERIAL PRIMARY KEY,
	user_id BIGINT UNSIGNED NOT NULL,	
	сomment VARCHAR(255), -- комментарий к заказу
	created_at DATETIME DEFAULT NOW(),
 	payment_type_id BIGINT UNSIGNED NOT NULL, 
	payment BIT DEFAULT 0, -- да/нет оплата, умолчание нет
	shipment BIT DEFAULT 0,  -- отгрузка 	
	FOREIGN KEY (payment_type_id) REFERENCES payment_type(id),
	FOREIGN KEY (user_id) REFERENCES users(id)
) COMMENT 'Заказы клиентов';

DROP TABLE IF EXISTS shop_catalog;
CREATE TABLE shop_catalog( 
	id SERIAL PRIMARY KEY,
	name VARCHAR(255) UNIQUE,
	INDEX idx_catalog (name)
);

DROP TABLE IF EXISTS description;
CREATE TABLE description(  -- не храним все это у себя а храним только ссылки
	id SERIAL PRIMARY KEY,
  	body text, -- текстовое описание
    url VARCHAR(255), -- ссылка на сайт производителя	
    created_at DATETIME DEFAULT NOW(),
    updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP
)COMMENT 'Ссылка на сайт производителя, описания';

DROP TABLE IF EXISTS product;
CREATE TABLE product( 
	id SERIAL PRIMARY KEY,
	article VARCHAR(255),
	name VARCHAR(255), 
	manufacturer VARCHAR(255), 
	shop_catalog_id BIGINT UNSIGNED NOT NULL,
	description BIGINT UNSIGNED NOT NULL DEFAULT '1', -- DEFAULT 1 'Описание для данного товара пока не появилось'
	FOREIGN KEY (shop_catalog_id) REFERENCES shop_catalog(id),
	FOREIGN KEY (description) REFERENCES description(id), -- ссылка на описание товара (фото, данные и тд)
	INDEX idx_manufacturer (manufacturer),
	INDEX idx_product_name(name)
); 

DROP TABLE IF EXISTS price_history;
CREATE TABLE price_history(
	product_id BIGINT UNSIGNED NOT NULL,
	price  DECIMAL (7,2) UNSIGNED NOT NULL,
	currency CHAR(3) DEFAULT 'RUB',
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	) ENGINE=Archive COMMENT 'Архив цен';

DROP TABLE IF EXISTS actual_price;
CREATE TABLE actual_price(
	product_id BIGINT UNSIGNED NOT NULL UNIQUE,
	price DECIMAL (7,2) UNSIGNED NOT NULL DEFAULT '0',
	currency CHAR(3) DEFAULT 'RUB',
	updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY (product_id) REFERENCES product(id)
	)COMMENT 'Актуальная действующая цена';

DROP TABLE IF EXISTS tax; -- ндс прибавляем сверху
CREATE TABLE tax( 
	id SERIAL PRIMARY KEY,
    tax BIGINT UNSIGNED NOT NULL UNIQUE,
    created_at DATETIME DEFAULT NOW(),
    updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP
)COMMENT 'Налоговая ставка НДС';

DROP TABLE IF EXISTS orders;
CREATE TABLE orders(
	order_id BIGINT UNSIGNED NOT NULL,  
	product_id BIGINT UNSIGNED NOT NULL,   -- товар
	quantity INT NOT NULL,  -- количество товара
	FOREIGN KEY (order_id) REFERENCES user_orders(id),
	FOREIGN KEY (product_id) REFERENCES product(id)
)COMMENT 'Номер заказа, состав заказа';

DROP TABLE IF EXISTS warehouse;
CREATE TABLE warehouse( -- склад
  product_id BIGINT UNSIGNED NOT NULL UNIQUE,
  value INT UNSIGNED COMMENT 'Запас товарной позиции на складе',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES product(id)
) COMMENT = 'Запасы на складе';

DROP TABLE IF EXISTS profiles;
CREATE TABLE profiles (
	user_id BIGINT UNSIGNED NOT NULL UNIQUE,
	password_hash VARCHAR(100),
	discount_id BIGINT UNSIGNED NOT NULL DEFAULT '1', -- ссылаемся на таблицу discout
	delivery_address VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  	FOREIGN KEY (user_id) REFERENCES users(id),
	FOREIGN KEY (discount_id) REFERENCES discount(id)
)COMMENT 'Профили покупателей';


/* Запуск триггеров для сохранения данных в истории цен */

DELIMITER ;

DROP TRIGGER IF EXISTS copy_to_history_on_insert;

DELIMITER //

CREATE TRIGGER copy_to_history_on_insert after insert ON actual_price
FOR EACH ROW
BEGIN
	insert into price_history (product_id, price, created_at)
		values (new.product_id , new.price , new.updated_at);
END //


DROP TRIGGER IF EXISTS copy_to_history_on_update//

CREATE TRIGGER copy_to_history_on_update after UPDATE ON actual_price
FOR EACH ROW
BEGIN
	insert into price_history (product_id, price, created_at)
		select product_id, price, updated_at 
		from actual_price
		where product_id = new.product_id and new.price != old.price;	
END //

DELIMITER ;


-- заполнение таблиц 

INSERT INTO discount (discount) 
	VALUES
	('0'),
	('2'),
	('4'),
	('5');
	
INSERT ignore INTO tax (tax) VALUES ('20');
  
INSERT INTO shop_catalog (name) 
	VALUES
	('Автоматические выключатели'),
	('Кабель и провод'),
	('Кабеленесущие системы'),
	('Лампы'),
	('Счетчики'),
	('Светильники'),
	('Розетки, выключатели'),
	('Щиты'),
	('Электромонтажные материалы');
	
INSERT INTO payment_type (payment) 
	VALUES
	('Наличные курьеру'),
	('Оплата на сайте банковской картой'),
	('Безналичная оплата через банк'),
	('Безналичная оплата юридическое лицо');
	
INSERT INTO users
VALUES 
	('1','Diamond','Brown','79735699990','dbogan@example.com'),
	('2','Brando','Schultz','79494737816','demario.lind@example.org'),
	('3','Charley','Harvey','79584728187','ycronin@example.org'),
	('4','Stuart','Hermann','79791833898','clementine.hane@example.net'),
	('5','Travon','Tremblay','79827926442','cecilia91@example.com'),
	('6','Jess','Carter','79850793370','stefan.gottlieb@example.org'),
	('7','Joe','Aufderhar','79579899703','ahalvorson@example.net'),
	('8','Soledad','Veum','79533913806','pollich.juvenal@example.com'),
	('9','Frankie','Abshire','79846511646','penelope.ryan@example.com'),
	('10','Ladarius','Conn','79003176948','gracie.dooley@example.com'),
	('11','Raphael','Moen','79471569342','gschmeler@example.com'),
	('12','Maximillian','Herzog','79368130351','maudie.beatty@example.com'),
	('13','Lambert','Anderson','79815496960','lee.adams@example.net'),
	('14','Nicklaus','Klocko','79340831679','bsawayn@example.org'),
	('15','Logan','Gerlach','79677786746','frami.sarai@example.net'),
	('16','Christop','Volkman','79046634516','adell68@example.net'),
	('17','Marc','Conn','79755064192','rosenbaum.reed@example.com'),
	('18','Tremaine','Kohler','79848475016','colton32@example.com'),
	('19','Jasen','Luettgen','79455915536','stiedemann.amya@example.net'),
	('20','Maxine','Pollich','79766125265','maynard48@example.com'),
	('21','Pietro','Brakus','79516418848','jovany.hegmann@example.org'),
	('22','Santa','Kihn','79477526035','qcasper@example.net'),
	('23','Jovany','White','79100747114','tobin46@example.net'),
	('24','Jedediah','Wilkinson','79394673520','xparker@example.com'),
	('25','Dewitt','Schaefer','79089430579','mosciski.name@example.net'),
	('26','Marcellus','Bayer','79728454357','jonathan80@example.com'),
	('27','John','Quigley','79462230635','schmeler.kenyatta@example.org'),
	('28','Austen','Rath','79868536378','tromp.opal@example.org'),
	('29','Keyon','Bogisich','79278183944','deonte.goyette@example.com'),
	('30','Keith','Parker','79906238350','jamel.hettinger@example.org'),
	('31','Terrence','Volkman','79783288521','krystal.borer@example.com'),
	('32','Tatum','Haag','79601662570','aprohaska@example.org'),
	('33','Wallace','Kassulke','79753000484','nicole.jacobi@example.com'),
	('34','Kris','Murray','79262623958','weber.jordane@example.com'),
	('35','Conor','Zieme','79687422059','ephraim.bailey@example.com'),
	('36','Jovany','Reinger','79925081017','earnestine.cronin@example.com'),
	('37','Olin','Bergstrom','79525631961','jerry.west@example.com'),
	('38','Elmer','Hilpert','79202862050','clarabelle.johnson@example.com'),
	('39','Charlie','Hoeger','79096005881','rae09@example.com'),
	('40','Travis','Bradtke','79753351153','dietrich.kenya@example.com'),
	('41','Jaime','Hansen','79068144998','maybelle48@example.net');

INSERT INTO profiles 
	VALUES 
	('1','042cccd58c4efbbc9477d14d2c846041d129d4b6','1','Москва, ул .Ленина 15','1986-02-02 09:44:11','1988-09-01 04:21:35'),
	('2','47c71c547dbdf46be086f0f3e3ef91a5195e6db2','2',NULL,'2009-05-20 17:33:45','2001-12-14 07:11:37'),
	('3','ce2625ebf3fd16c5515c008e62efad7d5ab87c30','3',NULL,'1985-03-20 00:03:09','1993-03-12 05:46:36'),
	('4','7824355615259146d08798c3b39f2b3330addf45','1','Казань, ул. Восстания 58','1997-12-20 01:23:48','1990-09-18 14:26:34'),
	('5','64952a2b9f0912fc98f622ab18e1318a8e696b72','4',NULL,'1998-10-05 10:08:05','1979-10-04 11:48:04'),
	('6','663fd8fa1f4e96557b6e1d7b71a9f5c5e3d8e685','3',NULL,'1989-05-05 15:58:07','1970-04-20 15:43:25'),
	('7','5cd15312ea33b244c94320e5768b7ae90958b018','1','Казань, ул. Восстания 58','2004-06-17 06:58:18','2004-08-07 05:38:09'),
	('8','623fae8e56c32b26e332ff74304a0825154dcdd5','4',NULL,'2003-10-29 02:31:54','2001-12-30 09:59:41'),
	('9','7cb355de330bdd0ad30314dcc06166353c590fef','3',NULL,'1993-12-17 22:18:57','1994-06-01 18:39:04'),
	('10','47c71c547dbdf46be086f0f3e3ef91a5195e6db2','2',NULL,'2009-05-20 17:33:45','2001-12-14 07:11:37'),
	('11','ce2625ebf3fd16c5515c008e62efad7d5ab87c30','3',NULL,'1985-03-20 00:03:09','1993-03-12 05:46:36'),
	('12','7824355615259146d08798c3b39f2b3330addf45','1','Казань, ул. Восстания 58','1997-12-20 01:23:48','1990-09-18 14:26:34'),
	('13','64952a2b9f0912fc98f622ab18e1318a8e696b72','4',NULL,'1998-10-05 10:08:05','1979-10-04 11:48:04'),
	('14','663fd8fa1f4e96557b6e1d7b71a9f5c5e3d8e685','3',NULL,'1989-05-05 15:58:07','1970-04-20 15:43:25'),
	('15','5cd15312ea33b244c94320e5768b7ae90958b018','1','Вологда ул. Мира 15','2004-06-17 06:58:18','2004-08-07 05:38:09'),
	('16','623fae8e56c32b26e332ff74304a0825154dcdd5','2',NULL,'2003-10-29 02:31:54','2001-12-30 09:59:41'),
	('17','7cb355de330bdd0ad30314dcc06166353c590fef','3',NULL,'1993-12-17 22:18:57','1994-06-01 18:39:04'),
	('18','47c71c547dbdf46be086f0f3e3ef91a5195e6db2','2',NULL,'2009-05-20 17:33:45','2001-12-14 07:11:37'),
	('19','ce2625ebf3fd16c5515c008e62efad7d5ab87c30','3','Москва, ул .Ленина 15','1985-03-20 00:03:09','1993-03-12 05:46:36'),
	('20','7824355615259146d08798c3b39f2b3330addf45','1',NULL,'1997-12-20 01:23:48','1990-09-18 14:26:34'),
	('21','64952a2b9f0912fc98f622ab18e1318a8e696b72','2','Казань, ул. Восстания 58','1998-10-05 10:08:05','1979-10-04 11:48:04'),
	('22','663fd8fa1f4e96557b6e1d7b71a9f5c5e3d8e685','3',NULL,'1989-05-05 15:58:07','1970-04-20 15:43:25'),
	('23','5cd15312ea33b244c94320e5768b7ae90958b018','1','Вологда ул. Мира 15','2004-06-17 06:58:18','2004-08-07 05:38:09'),
	('24','623fae8e56c32b26e332ff74304a0825154dcdd5','2',NULL,'2003-10-29 02:31:54','2001-12-30 09:59:41'),
	('25','7cb355de330bdd0ad30314dcc06166353c590fef','4',NULL,'1993-12-17 22:18:57','1994-06-01 18:39:04'),
	('26','47c71c547dbdf46be086f0f3e3ef91a5195e6db2','2','Екатеринбург ул. Восточная 54','2009-05-20 17:33:45','2001-12-14 07:11:37'),
	('27','ce2625ebf3fd16c5515c008e62efad7d5ab87c30','3',NULL,'1985-03-20 00:03:09','1993-03-12 05:46:36'),
	('28','7824355615259146d08798c3b39f2b3330addf45','1',NULL,'1997-12-20 01:23:48','1990-09-18 14:26:34'),
	('29','64952a2b9f0912fc98f622ab18e1318a8e696b72','3',NULL,'1998-10-05 10:08:05','1979-10-04 11:48:04'),
	('30','663fd8fa1f4e96557b6e1d7b71a9f5c5e3d8e685','3',NULL,'1989-05-05 15:58:07','1970-04-20 15:43:25'),
	('31','5cd15312ea33b244c94320e5768b7ae90958b018','1',NULL,'2004-06-17 06:58:18','2004-08-07 05:38:09'),
	('32','623fae8e56c32b26e332ff74304a0825154dcdd5','2','Екатеринбург ул. Восточная 54','2003-10-29 02:31:54','2001-12-30 09:59:41'),
	('33','7cb355de330bdd0ad30314dcc06166353c590fef','3',NULL,'1993-12-17 22:18:57','1994-06-01 18:39:04'),
	('34','47c71c547dbdf46be086f0f3e3ef91a5195e6db2','2',NULL,'2009-05-20 17:33:45','2001-12-14 07:11:37'),
	('35','ce2625ebf3fd16c5515c008e62efad7d5ab87c30','3','Вологда ул. Мира 15','1985-03-20 00:03:09','1993-03-12 05:46:36'),
	('36','7824355615259146d08798c3b39f2b3330addf45','1',NULL,'1997-12-20 01:23:48','1990-09-18 14:26:34'),
	('37','64952a2b9f0912fc98f622ab18e1318a8e696b72','2',NULL,'1998-10-05 10:08:05','1979-10-04 11:48:04'),
	('38','663fd8fa1f4e96557b6e1d7b71a9f5c5e3d8e685','3','Екатеринбург ул. Восточная 54','1989-05-05 15:58:07','1970-04-20 15:43:25'),
	('39','5cd15312ea33b244c94320e5768b7ae90958b018','1',NULL,'2004-06-17 06:58:18','2004-08-07 05:38:09'),
	('40','623fae8e56c32b26e332ff74304a0825154dcdd5','2',NULL,'2003-10-29 02:31:54','2001-12-30 09:59:41'),
	('41','7cb355de330bdd0ad30314dcc06166353c590fef','3','Вологда ул. Мира 15','1993-12-17 22:18:57','1994-06-01 18:39:04');

INSERT INTO description (id, body, url) 
	VALUES
	('1','Описание для данного товара еще не добавлено', NULL),
	('2','Выключатель автоматический пр-ва АВВ','http://www.abb.com'),
	('3','Выключатель автоматический пр-ва Schneider Electric','http://www.SE.com'),
	('4','Выключатель автоматический пр-ва EKF','http://altenwerth.org/'),
	('5','Sint quaerat aut est quae ducimus. Odit asperiores minus consequuntur quia. Temporibus et molestiae aut occaecati consequuntur quo. Dolor corporis omnis quia.','http://www.kreiger.com/'),
	('6','Laudantium corrupti reiciendis totam eos. Sed aspernatur est qui fuga. Ratione expedita quidem at libero expedita iste.','http://www.cummings.net/'),
	('7','Culpa sed quibusdam omnis. Quibusdam impedit debitis unde assumenda aut reprehenderit voluptatem. Et sint aliquid quia expedita sed atque ut. Ipsam esse dolores velit reiciendis laboriosam amet.','http://eichmann.com/'),
	('8','Qui perspiciatis consequuntur sint. Et eum incidunt atque in ea. Quia magnam fugit reiciendis aut pariatur et animi explicabo. Repellat dolor et natus architecto qui vel modi. Autem impedit id voluptas necessitatibus voluptates esse.','http://morarnolan.com/'),
	('9','Quidem omnis omnis repellat sunt magni voluptatem ratione. Rerum autem totam nihil nihil quasi nihil pariatur. Sapiente inventore quia omnis nisi illum laboriosam quis quis. At quis eveniet sint voluptates culpa.','http://www.mrazcartwright.com/'),
	('10','Asperiores eaque nisi suscipit et velit ratione. Ipsum non nobis omnis reprehenderit fuga dolor nemo. Et est itaque numquam quas est. Rerum error sint voluptatem.','http://wintheisergerlach.biz/'),
	('11','Dolore eos reiciendis non sed cupiditate debitis. Eligendi beatae aut repudiandae et omnis. Minus maiores eum non dolor. Id optio maiores qui enim rerum perspiciatis.','http://schamberger.info/'),
	('12','Est sed deserunt perferendis. Voluptatem atque magni id officiis. Voluptatem in quo consequuntur eum iste eos natus. Quaerat voluptatum delectus sit quibusdam ratione numquam.','http://www.croninpaucek.biz/'),
	('13','Quas commodi iure similique eligendi sunt. Consectetur debitis corporis error consequatur nesciunt aut. Earum qui et asperiores eius. Voluptatem unde laborum cumque ut quia ducimus.','http://toy.biz/'),
	('14','Porro repudiandae nam facilis veniam voluptas. Autem illum et magni dolore. Laudantium libero impedit temporibus.','http://gibsoncole.com/'),
	('15','Rerum fuga enim veniam dignissimos cumque vel eligendi nisi. Sequi at consequuntur consectetur optio. Molestiae earum vel aut culpa aperiam asperiores.','http://www.dickensaltenwerth.net/'),
	('16','Repellendus dolores eius laborum eligendi. Error molestias et pariatur porro adipisci. Et dicta quod ea nihil accusamus.','http://von.com/'),
	('17','Voluptas qui officiis nisi. Explicabo quisquam deserunt occaecati enim accusamus at. In officiis et velit amet tempore a corporis.','http://www.collinsdeckow.com/'),
	('18','Et commodi sed ut. Alias autem eos fugiat vitae. Unde magni suscipit non fugit.','http://www.funk.com/'),
	('19','Harum est aliquam eos qui numquam atque. Sapiente voluptatem quo unde sit corrupti cum placeat temporibus. Sit corrupti dicta praesentium earum saepe. Ut temporibus maiores ullam sit delectus mollitia.','http://donnelly.com/'),
	('20','Aliquam sapiente facere dolorum repellat et voluptatibus in. Dolor et nisi et voluptatum sit perspiciatis. Quia delectus architecto recusandae voluptatem distinctio. Perferendis sit nesciunt sunt repellendus enim. Illum totam soluta repellat unde hic qui.','http://www.ward.com/'),
	('21','Commodi nostrum aut animi et ea voluptatem. In officiis assumenda debitis ipsam ut. Id ipsum dolor tempore autem cumque sunt tempora. Sunt in asperiores perspiciatis rem. Consequatur voluptas hic unde numquam aut ratione et.','http://www.reillybergstrom.biz/'),
	('22','Accusantium unde sed vero alias enim aut. Eos eveniet voluptas ut odit odio molestiae. Molestiae ratione esse ex eligendi laboriosam beatae. Iusto iure eveniet explicabo vero.','http://www.smithpadberg.com/'),
	('23','Aut assumenda atque aut ea repellendus. Quaerat et perspiciatis quia quo quas consequatur.','http://beatty.com/'),
	('24','Voluptates sunt ea ipsam sit aspernatur aliquam possimus qui. Reprehenderit excepturi illum et labore. Voluptas veritatis velit magni ullam.','http://schoen.net/'),
	('25','Voluptatum et iure et laborum rem voluptatem consequatur. Autem est est dolore vel et a. Non iste iure sed. Qui nam labore consequatur eum ipsam sit.','http://goyette.com/'),
	('26','Nemo nemo aliquam mollitia aut alias. Sunt velit alias vel iste. Et aperiam voluptas optio laudantium officia beatae.','http://zulaufeichmann.net/'),
	('27','Cupiditate nobis sunt qui esse. Aliquid nesciunt alias voluptatem doloremque cumque et ex. Expedita commodi deleniti quia eaque velit velit eligendi. Et non veniam inventore enim necessitatibus sint quo.','http://www.runte.com/'),
	('28','Aliquam voluptatem quia reprehenderit libero adipisci ut velit. Quis blanditiis rem veritatis est esse voluptas perspiciatis. Soluta iste consequatur tempore quaerat sit voluptatem sit.','http://kreigerlegros.net/'),
	('29','Omnis delectus occaecati quia et. Consequatur nihil aut magnam eaque aut distinctio. Et ratione vero et et harum voluptas deserunt cupiditate. Et sit enim reprehenderit voluptas rerum qui modi autem.','http://pfeffer.biz/'),
	('30','Aut voluptatibus doloribus ea ut pariatur dolore. Est nisi molestiae rerum hic est dicta. Doloremque dolorem accusantium dicta eos omnis ad eveniet. Et libero quidem recusandae fuga voluptas sequi.','http://beierschaefer.com/'),
	('31','Optio similique qui repudiandae sunt delectus odit excepturi. Labore pariatur at eum a laboriosam iste eum.','http://eichmann.com/'),
	('32','Porro ex repudiandae ullam. Illo blanditiis nisi eos odit sunt veritatis. Maxime impedit quae quia sapiente.','http://connelly.com/'),
	('33','Quam sequi sint occaecati cumque culpa. Alias molestiae ex sunt officia. Aut nulla quos ea quaerat sint ut et alias.','http://www.rath.info/'),
	('34','Culpa harum ut et esse quis. Magni quo facilis ea cum consectetur. Asperiores nesciunt dolores suscipit voluptatem aut.','http://www.pfannerstillzboncak.biz/'),
	('35','Commodi asperiores et quam modi esse consequatur id. Et consectetur nam est ipsam hic sit sit. Eaque reiciendis ea in neque consequatur nulla sed. Aperiam iure repudiandae quas aut sit.','http://gerhold.com/'),
	('36','Non quia et facilis excepturi quasi saepe. Pariatur et aliquid earum eveniet omnis pariatur. Repudiandae error quas ad blanditiis ut qui distinctio. Adipisci rerum eum quos voluptas ut.','http://schulist.biz/'),
	('37','Explicabo atque fuga sit quo voluptatem. Fugiat ut quae soluta est fugiat nesciunt harum. Ut consequatur quia commodi possimus nulla. Accusantium nobis non et omnis dicta animi.','http://pfefferskiles.net/'),
	('38','Sint quos est et maxime assumenda. Modi totam quia sed sed nisi dignissimos quis. Eaque iusto sunt non eum ut soluta fuga. Suscipit dolore itaque autem quia.','http://reynolds.net/'),
	('39','Et vel fugiat doloribus mollitia natus est. Labore temporibus rerum provident ex. At impedit qui assumenda aut quas sequi. Porro sint fugiat voluptatem ipsam tenetur et.','http://hyattbogan.net/'),
	('40','Assumenda nihil necessitatibus magni sunt at hic. Et earum quia in id unde. Voluptatem at itaque libero doloribus et. Distinctio at vel magnam non rerum architecto.','http://www.wiegand.com/'),
	('41','Et minima voluptates dicta vitae dignissimos. Esse ut dolores maxime similique impedit. Natus vel rerum a recusandae modi. Consequatur et autem dignissimos itaque assumenda quia fugiat. Omnis aut est rerum dolores provident quidem voluptas.','http://rutherford.com/'),
	('42','Eaque fuga ex quia laudantium qui est. Ea veritatis magni hic iste et aut quia at. Quas qui incidunt repellat aspernatur et deserunt.','http://abernathy.com/'),
	('43','Nihil ipsa unde iusto fuga architecto sunt. Ut consequatur earum et non vel eveniet.','http://www.christiansen.com/'),
	('44','Qui voluptatem ut et laudantium. Dolorum eos aspernatur autem ab sed. Ut perspiciatis rerum excepturi ut.','http://www.parker.org/'),
	('45','Ipsum dolorem mollitia voluptas iure itaque aut. Iure consequatur amet numquam quas excepturi. Ut et molestias sit tempore quam.','http://www.torp.com/'),
	('46','Dolorem in numquam voluptas quo id ut. Quisquam veniam reprehenderit adipisci in. Nihil sed voluptas dolorem. Vitae inventore dolore dicta impedit et dolor soluta.','http://www.smitham.org/'),
	('47','Quasi veritatis fuga maxime. Est quis porro itaque veniam dolor qui. Est eos sit deleniti.','http://muellercummings.biz/'),
	('48','Accusantium tempora id sit. Reprehenderit explicabo reprehenderit illum eum voluptate sit voluptas. Rem facilis qui dolor eius perspiciatis dolorum. Labore dolorem debitis minima sed.','http://www.ondricka.com/'),
	('49','Culpa repudiandae consequatur autem. Minus itaque ipsam non. Facere tenetur architecto delectus numquam necessitatibus molestiae.','http://www.brakus.com/'),
	('50','Culpa repudiandae consequatur autem. Minus itaque ipsam non. Facere tenetur architecto delectus numquam necessitatibus molestiae.','http://www.brakus.com/'),
	('51','Culpa repudiandae consequatur autem. Minus itaque ipsam non. Facere tenetur architecto delectus numquam necessitatibus molestiae.','http://www.brakus.com/'),
	('52','Autem quas atque ut doloribus id consequuntur nihil. Quo qui error voluptas quo.','http://www.volkman.com/'); 

INSERT INTO product (article, name, manufacturer, shop_catalog_id, description) 
	VALUES
	('s2c42416', 'Автоматический выключатель 1-полюсный 16А', 'ABB', '1', '2'),
	('s2c42406', 'Автоматический выключатель 1-полюсный 6А', 'ABB', '1', '2'),
	('s2c42425', 'Автоматический выключатель 1-полюсный 25А', 'ABB', '1', '2'),
	('e9f34516', 'Автоматический выключатель 1-полюсный 16А', 'Schneider Electric', '1', '3'),
	('e9f34316', 'Автоматический выключатель 3-полюсный 16А', 'Schneider Electric', '1', '3'),
	('e9f34225', 'Автоматический выключатель 2-полюсный 25А', 'Schneider Electric', '1', '3'),
	('ekf12235', 'Автоматический выключатель 1-полюсный 10А', 'ekf', '1', '4'),
	('ВВГнг 3х1,5', 'Кабель ВВГнг 3х1,5', 'ЭКЗ', '2', '4'),
	('ВВГнг 3х2,5', 'Кабель ВВГнг 3х2,5', 'ЭКЗ', '2', '5'),
	('ВВГнг 2х1,5', 'Кабель ВВГнг 2х1,5', 'КамКабель', '2', '6'),
	('ВВГнг 2х2,5', 'Кабель ВВГнг 2х2,5', 'КамКабель', '2', '7'),
	('UTP 5e', 'Кабель интернет UTP 4х2х0,5', 'Cavel', '2', '8'),
	('ШВВП 2х0,5', 'Шнур 2х0,5', 'Уралкабель', '2', '9'),
	('SAT 50m', 'Кабель ТВ', 'Cavel', '2', '10'),
	('01245', 'Кабель канал 40х20', 'ДКС', '3', '11'),
	('01247', 'Кабель канал 60х40', 'ДКС', '3', '12'),
	('91920', 'Труба гибкая легкая с протяжкой d20', 'ДКС', '3', '13'),
	('91925', 'Труба гибкая легкая с протяжкой d25', 'ДКС', '3', '14'),
	('fx4578', 'Лоток штампованный 100х50', 'ИЕК', '3', '15'),
	('fx4485', 'Лоток перфорированный 100х50', 'ИЕК', '3', '16'),
	('fc4575', 'Кабель канал 20х20', 'ИЕК', '3', '17'),
	('01458', 'Кабель канал 20х20', 'ДКС', '3', '18'),
	('led A60 14', 'Лампа светодиодная 14 Вт e27', 'Philips', '4', '19'),
	('lamp 10', 'Лампа светодиодная 10 Вт', 'Osram', '4', '20'),
	('led A60 14-1', 'Лампа светодиодная 10 Вт e14', 'Philips', '4', '21'),
	('led A60 10', 'Лампа светодиодная 10 Вт', 'Philips', '4', '22'),
	('led A60 14', 'Лампа светодиодная 14 Вт', 'Philips', '4', '23'),
	('lamp 5', 'Лампа светодиодная 4 Вт', 'Osram', '4', '24'),
	('ЛН60', 'Лампа накаливания 60 Вт е27', 'Лисма', '4', '25'),
	('lr round 01', 'Светильник встроенный светодиодный 14 Вт d120', 'Philips', '6', '26'),
	('lr square 01', 'Светильник встроенный светодиодный 14 Вт 60х60', 'Philips', '6', '27'),
	('Опал 595х595', 'Светильник встр/накл светодиодный 36 Вт армстронг', 'Jazzway', '6', '28'),
	('Призма 595х595', 'Светильник встр/накл светодиодный 36 Вт армстронг призма', 'Jazzway', '6', '29'),
	('fr4501', 'Светильник встроенный точка d51 белый', 'Свет', '6', '30'),
	('fr4502', 'Светильник встроенный точка d51 серебро', 'Свет', '6', '31'),
	('ce102r', 'Счетчик э/энергии 1 фазный однотарифный 5-60А', 'Энергомера', '5', '32'),
	('ce105r', 'Счетчик э/энергии 1 фазный двухтарифный 5-60А', 'Энергомера', '5', '33'),
	('ce302r', 'Счетчик э/энергии 3 фазный однотарифный 5-100А', 'Энергомера', '5', '34'),
	('ce312r', 'Счетчик э/энергии 3 фазный однотарифный 5-60А', 'Энергомера', '5', '35'),
	('ce322r', 'Счетчик э/энергии 3 фазный двухтарифный 5-100А', 'Энергомера', '5', '36'),
	('454007', 'Розетка 2p+e белая Valena', 'Legrand', '7', '37'),
	('454017', 'Розетка 2p+e серебро Valena', 'Legrand', '7', '37'),
	('454447', 'Выключатель 1-кл белый Valena', 'Legrand', '7', '37'),
	('454407', 'Выключатель 2-кл белый Valena', 'Legrand', '7', '37'),
	('ad34355', 'Розетка 2p+e серебро Atlas Design', 'Schneider Electric', '7', '41'),
	('ad34655', 'Розетка 2p+e белая Atlas Design', 'Schneider Electric', '7', '41'),
	('ad34255', 'Выключатель 2-кл белый Atlas Design', 'Schneider Electric', '7', '41'),
	('ad34356', 'Выключатель 1-кл белый Atlas Design', 'Schneider Electric', '7', '41'),
	('254027', 'Розетка 2p+e белая Etika', 'Legrand', '7', '42'),
	('254017', 'Розетка 2p+e белая Etika', 'Legrand', '7', '42'),
	('254037', 'Розетка 2p+e белая Etika', 'Legrand', '7', '42'),
	('84785', 'Щит встраиваемый 12 мод', 'Legrand', '8', '43'),
	('84755', 'Щит встраиваемый 24 мод', 'Legrand', '8', '44'),
	('re456', 'Щит накладной 12 мод', 'ИЕК', '8', '45'),
	('re455', 'Щит накладной 24 мод', 'ИЕК', '8', '46'),
	('ykm3456', 'Щит встраиваемый 36 мод', 'ДКС', '8', '47'),
	('ykm3546', 'Щит накладной 36 мод', 'ДКС', '8', '48'),
	('КУ1101', 'Коробка установочная 68х42 бетон', 'Hegel', '9', '49'),
	('КУ1201', 'Коробка установочная 68х42 гкл', 'Hegel', '9', '50'),
	('58400', 'Коробка установочная 80х70х42 накладной монтаж', 'ДКС', '9', '51'),
	('45242', 'Изоляционная лента 19х20 черная', 'SafeLine', '9', '1'),
	('45243', 'Изоляционная лента 19х20 синяя', 'SafeLine', '9', '1'),
	('45000', 'Хомут кабельный 4,2х250', 'ДКС', '9', '52');
	
INSERT INTO warehouse (product_id, value) 
	VALUES
	('1', '0'),
	('2', '10'),
	('3', '14'),
	('4', '10'),
	('5', '3'),
	('6', '4'),
	('7', '0'),
	('8', '1000'),
	('9', '1400'),
	('10', '100'),
	('11', '0'),
	('12', '1000'),
	('13', '120'),
	('14', '105'),
	('15', '3'),
	('16', '4'),
	('17', '0'),
	('18', '10'),
	('19', '14'),
	('20', '10'),
	('21', '0'),
	('22', '10'),
	('23', '14'),
	('24', '10'),
	('25', '3'),
	('26', '4'),
	('27', '0'),
	('28', '10'),
	('29', '14'),
	('30', '10'),
	('31', '20'),
	('32', '10'),
	('33', '14'),
	('34', '10'),
	('35', '3'),
	('36', '4'),
	('37', '40'),
	('38', '10'),
	('39', '14'),
	('40', '10'),
	('41', '20'),
	('42', '10'),
	('43', '14'),
	('44', '10'),
	('45', '3'),
	('46', '4'),
	('47', '40'),
	('48', '10'),
	('49', '14'),
	('50', '10'),
	('51', '20'),
	('52', '10'),
	('53', '14'),
	('54', '10'),
	('55', '3'),
	('56', '4'),
	('57', '40'),
	('58', '10'),
	('59', '14'),
	('60', '10'),
	('61', '10'),
	('62', '14'),
	('63', '10');
	
INSERT INTO actual_price (product_id, price, updated_at) 
	VALUES
	('1', '40.04','2020-05-05 15:58:07'),
	('2', '10','2020-05-05 15:58:07'),
	('3', '14','2020-05-05 15:58:07'),
	('4', '10','2020-05-05 15:58:07'),
	('5', '3.05','2020-05-05 15:58:07'),
	('6', '4','2020-05-05 15:58:07'),
	('7', '20','2020-05-05 15:58:07'),
	('8', '10','2020-05-05 15:58:07'),
	('9', '14.54','2020-05-05 15:58:07'),
	('10', '100','2020-05-05 15:58:07'),
	('11', '11.2','2020-05-05 15:58:07'),
	('12', '11.6','2020-05-05 15:58:07'),
	('13', '12','2020-05-05 15:58:07'),
	('14', '10.5','2020-05-05 15:58:07'),
	('15', '3','2020-05-05 15:58:07'),
	('16', '4','2020-05-05 15:58:07'),
	('17', '50','2020-05-05 15:58:07'),
	('18', '10','2020-05-05 15:58:07'),
	('19', '14','2020-05-05 15:58:07'),
	('20', '10','2020-05-05 15:58:07'),
	('21', '6.0','2020-05-05 15:58:07'),
	('22', '10','2020-05-05 15:58:07'),
	('23', '14','2020-05-05 15:58:07'),
	('24', '10','2020-05-05 15:58:07'),
	('25', '3','2020-05-05 15:58:07'),
	('26', '4','2020-05-05 15:58:07'),
	('27', '80','2020-05-05 15:58:07'),
	('28', '10','2020-05-05 15:58:07'),
	('29', '14','2020-05-05 15:58:07'),
	('30', '10','2020-05-05 15:58:07'),
	('31', '20','2020-05-05 15:58:07'),
	('32', '10.8','2020-05-05 15:58:07'),
	('33', '14','2020-05-05 15:58:07'),
	('34', '104','2020-05-05 15:58:07'),
	('35', '3','2020-05-05 15:58:07'),
	('36', '4','2020-05-05 15:58:07'),
	('37', '40','2020-05-05 15:58:07'),
	('38', '10','2020-05-05 15:58:07'),
	('39', '14','2020-05-05 15:58:07'),
	('40', '10','2020-05-05 15:58:07'),
	('41', '20','2020-05-05 15:58:07'),
	('42', '10','2020-05-05 15:58:07'),
	('43', '14','2020-05-05 15:58:07'),
	('44', '10','2020-05-05 15:58:07'),
	('45', '3','2020-05-05 15:58:07'),
	('46', '4','2020-05-05 15:58:07'),
	('47', '40','2020-05-05 15:58:07'),
	('48', '10','2020-05-05 15:58:07'),
	('49', '14','2020-05-05 15:58:07'),
	('50', '10','2020-05-05 15:58:07'),
	('51', '20','2020-05-05 15:58:07'),
	('52', '10','2020-05-05 15:58:07'),
	('53', '14.45','2020-05-05 15:58:07'),
	('54', '10','2020-05-05 15:58:07'),
	('55', '35','2020-05-05 15:58:07'),
	('56', '4','2020-05-05 15:58:07'),
	('57', '40','2020-05-05 15:58:07'),
	('58', '10','2020-05-05 15:58:07'),
	('59', '14','2020-05-05 15:58:07'),
	('60', '108','2020-05-05 15:58:07'),
	('61', '10','2020-05-05 15:58:07'),
	('62', '14','2020-05-05 15:58:07'),
	('63', '10','2020-05-05 15:58:07');
	
  INSERT INTO user_orders (user_id, payment_type_id) 
	VALUES
	('1', '4'),
	('12', '3'),
	('32', '4'),
	('41', '2'),
	('5', '3'),
	('6', '4'),
	('17', '3'),
	('8', '2'),
	('32', '4'),
	('18', '1'),
	('11', '1'),
	('32', '2'),
	('18', '3'),
	('11', '1');

INSERT INTO orders (order_id, product_id, quantity)
	VALUES
	('1', '4', '15'),
	('2', '5', '1'),
	('14', '6', '9'),
	('13', '9', '3'),
	('12', '10', '1'),
	('11', '1', '3'),
	('10', '14', '4'),
	('9', '10', '14'),
	('8', '6', '3'),
	('7', '3', '24'),
	('6', '25', '8'),
	('5', '63', '6'),
	('4', '48', '10'),
	('3', '52', '4'),
	('11', '60', '12'),
	('1', '35', '14'),
	('10', '37', '8'),
	('5', '60', '4'),
	('6', '47', '2'),
	('8', '20', '4'),
	('2', '50', '8'),
	('5', '42', '5'),
	('11', '11', '4'),
	('13', '33', '7'),
	('1', '16', '5'),
	('14', '55', '20'),
	('7', '25', '1'),
	('8', '22', '4'),
	('9', '46', '5'),
	('10', '6', '7'),
	('11', '44', '10');
	
-- пример для проверки триггера по update

UPDATE actual_price 
	SET price = '41.04'
		WHERE product_id = 1; 
	
-- SELECT * FROM price_history;
	
-- вьюшка с полной информацией по заказу (кол-во едениц в заказе, цена до скидки, со скидкой, и с налогами)

CREATE OR REPLACE VIEW complete_information AS

SELECT orders.order_id, sum(orders.quantity) AS number_of_units,
sum(actual_price.price*orders.quantity) AS summ,TRUNCATE(sum(actual_price.price*orders.quantity)*(1-(discount.discount)/100),2) AS summ_with_discount,
TRUNCATE(sum((actual_price.price*orders.quantity)*(1-(discount.discount)/100)) * (1+(tax.tax)/100),2) AS total_price_with_tax, 'RUB' AS currency 
	FROM orders
JOIN actual_price on orders.product_id = actual_price.product_id 
JOIN user_orders on user_orders.id = orders.order_id 
JOIN users on users.id = user_orders.user_id 
JOIN profiles on profiles.user_id = users.id
JOIN discount on discount.id = profiles.discount_id
JOIN tax ON tax.id = 1

GROUP BY orders.order_id
ORDER BY order_id;

-- выборка из вьюшки complete_information
-- SELECT order_id, number_of_units, total_price_with_tax, currency FROM complete_information where order_id = 10; 

-- вьюшкa каталог с ндс и без
CREATE OR REPLACE VIEW catalog_information AS

SELECT 
	product.name, manufacturer, price, TRUNCATE(price*(1+(tax.tax)/100),2) AS price_tax, currency
  FROM product
    JOIN actual_price ON product.id = actual_price.product_id
    JOIN shop_catalog ON shop_catalog.id = product.shop_catalog_id 
    JOIN tax ON tax.id = 1
  		WHERE shop_catalog.id = 4;  -- выборка по 4 категории (лампы)
  	
 -- SELECT * FROM catalog_information;
 
 -- вьюшка 'просмотр состава заказа' 
 
CREATE OR REPLACE VIEW order_information AS 

SELECT product_id, name, quantity 
	FROM orders 
		JOIN product  on orders.product_id = product.id 
			WHERE order_id = '1';
			
-- SELECT * FROM order_information;

-- вьюшка показывает у какого пользователя какая скидка в %
CREATE OR REPLACE VIEW users_information AS 
 
SELECT CONCAT(users.firstname, ' ', users.lastname) AS user_info , discount, '%' 
	FROM users
		JOIN profiles on profiles.user_id = users.id
		JOIN discount on discount.id = profiles.discount_id
			ORDER BY users.id;

-- SELECT * FROM users_information;


