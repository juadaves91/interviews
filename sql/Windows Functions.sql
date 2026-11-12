-- setup

CREATE TABLE ventas (
  id INTEGER PRIMARY KEY,
  vendedor TEXT,
  region TEXT,
  mes INTEGER,
  monto REAL
);

INSERT INTO ventas VALUES
(1,'Ana','Norte',1,1200),(2,'Ana','Norte',2,1500),
(3,'Ana','Norte',3,1100),(4,'Ana','Norte',4,1800),
(5,'Bob','Sur',1,900),(6,'Bob','Sur',2,1300),
(7,'Bob','Sur',3,1700),(8,'Bob','Sur',4,1100),
(9,'Carlos','Norte',1,2000),(10,'Carlos','Norte',2,1600),
(11,'Carlos','Norte',3,1900),(12,'Carlos','Norte',4,2200),
(13,'Diana','Sur',1,800),(14,'Diana','Sur',2,950),
(15,'Diana','Sur',3,1050),(16,'Diana','Sur',4,1200);

/*
 1. Numera todas las ventas en orden de monto de mayor a menor.
 
	Que hace cada parte:
	--------------------
	
	- ROW_NUMBER() asigna un numero unico a cada fila: 1, 2, 3... sin saltos, sin repeticiones.
	
	- OVER (...) es la palabra clave que convierte esto en una window function. 
	  Sin OVER, SQL no sabria que quieres ver todas las filas. 
	  Con OVER le dices: no colapses nada, solo calcula este valor para cada fila mirando a las demas.
	
	- ORDER BY monto DESC dentro del OVER le dice en que orden numerar.
	  El monto mas alto recibe el numero 1, el segundo mas alto el 2, y asi.
	
	Resultado esperado:
	-------------------
	
	Veran 16 filas. La venta de Carlos en mes 4 (monto 2200) tendra posicion 1. La de Diana en mes 1 (monto 800) 
	tendra posicion 16. La tabla no se colapsa — siguen siendo 16 filas, ahora con una columna extra.
	
	La diferencia clave con GROUP BY:
	Si hicieras SELECT vendedor, MAX(monto) FROM ventas GROUP BY vendedor obtendrias 4 filas (una por vendedor). 
	Con la window function obtienes 16 filas con informacion adicional en cada una. Esa es la idea central.
*/

SELECT
  vendedor,
  mes,
  monto,
  ROW_NUMBER() OVER (ORDER BY monto DESC) AS posicion_global
FROM ventas;


/*
2. Numera las ventas de cada vendedor por mes, reiniciando el contador por vendedor (Nivel 2 — PARTITION BY).
   
   Que hace cada parte:
   --------------------
   
	- PARTITION BY vendedor: es el concepto nuevo aqui. Le dice a SQL: divide la tabla en grupos separados por vendedor, 
	                         y aplica la funcion dentro de cada grupo de forma independiente.
	
	- Sin PARTITION BY, SQL ve una sola ventana con 16 filas. 
	- Con PARTITION BY vendedor, SQL ve 4 ventanas separadas:
	                    [ Ana: 4 filas ]   
	                    [ Bob: 4 filas ]  
	                    [ Carlos: 4 filas ]   
	                    [ Diana: 4 filas ]
	
	- El ROW_NUMBER empieza desde 1 en cada grupo:
	          Ana mes 1 = fila 1,
	          Ana mes 2 = fila 2.
	          Luego Bob mes 1 = fila 1 de nuevo. (El contador reinicia).
	
	- ORDER BY mes dentro del OVER decide el orden dentro de cada grupo. 
	           El mes 1 de cada vendedor sera la fila numero 1.
	
	
	Resultado esperado:
	-------------------
	
	Las 16 filas siguen ahi. La columna mes_num va del 1 al 4 para cada vendedor por separado. 
	Si quitaras el PARTITION BY, la columna iria del 1 al 16 de corrido para todos.
	
	Cuando usar PARTITION BY:
	Siempre que quieras calcular algo por grupo sin colapsar las filas. Rankings por categoria, 
	acumulados por cliente, comparaciones dentro de un departamento.   
      
*/


 SELECT
	  vendedor,
	  mes,
	  monto,
	  ROW_NUMBER() OVER (PARTITION BY vendedor ORDER BY mes) AS mes_num
FROM ventas;


/*
3. Rankea a los vendedores por monto total.
   Verás la diferencia entre (RANK y DENSE_RANK) cuando hay empates.
   
   Que hace cada parte:
   --------------------
   
	Aqui usas el mismo OVER dos veces con funciones distintas. 
	SQL calcula cada columna de forma independiente.
	
	
	- RANK() rankea las filas dentro de cada region por monto. 
	  El problema: si dos filas tienen el mismo monto, ambas reciben el mismo numero, 
	  y el siguiente numero se salta. Ejemplo: si hay dos filas con rank 2, la siguiente es rank 4 (no 3).
	  Como en una competencia real: dos personas en segundo lugar, nadie en tercero.
	 
	- DENSE_RANK() hace lo mismo pero sin saltarse numeros. Si hay dos filas con rank 2, la siguiente es rank 3. 
	  Los rangos son consecutivos siempre.
	  
	 Cuando usar cada uno:
	 ---------------------
	
	 - Usa RANK() cuando quieras reflejar posiciones reales (como atletismo: si dos atletas empatan en segundo, el siguiente es cuarto).
	 - Usa DENSE_RANK() cuando quieras saber cuantos niveles distintos hay (si hay 3 niveles de salario, DENSE_RANK te da 1, 2, 3 sin 
	   importar cuantos empaten en cada nivel).
	 
	 Resultado esperado:
	 -------------------
	 En la region Norte hay 8 filas (Ana y Carlos, 4 meses cada uno). 
	 Veras como los montos de Carlos suelen ser mas altos y reciben rank 1 o 2.
	 Cuando dos montos sean iguales o muy cercanos, podras ver la diferencia entre RANK y DENSE_RANK en accion.
  */

-- Usamos un CTE con empates intencionales para ver la diferencia real:
WITH datos AS (
  SELECT 'Ana'    AS vendedor, 1500 AS monto
  UNION ALL SELECT 'Bob',    1500
  UNION ALL SELECT 'Carlos', 1200
  UNION ALL SELECT 'Diana',   900
  UNION ALL SELECT 'Elena',   900
)
SELECT
  vendedor,
  monto,
  RANK()       OVER (ORDER BY monto DESC) AS rank_resultado,
  DENSE_RANK() OVER (ORDER BY monto DESC) AS dense_rank_resultado
FROM datos;


/*
4. Calcula el monto acumulado por vendedor mes a mes (Nivel 4 — SUM acumulado).

	- SUM(monto) suma montos. Eso ya lo conoces. El cambio esta en el OVER.
	
	- PARTITION BY vendedor divide por vendedor. El acumulado reinicia con cada vendedor.
	
	- ORDER BY mes define el orden en que se acumula. Mes 1 primero, mes 2 segundo, etc.
	
	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW es el frame, y es la parte nueva. 
	Le dice a SQL exactamente que filas incluir en el calculo para cada fila:
	
	• UNBOUNDED PRECEDING = desde la primera fila del grupo (sin limite hacia atras)
	• CURRENT ROW = hasta la fila actual
	
	Entonces para cada fila, SQL suma desde el inicio del grupo hasta esa fila. 
	  Para el mes 1: solo mes 1.
	  Para el mes 2: mes 1 + mes 2.
	  Para el mes 3: mes 1 + mes 2 + mes 3.
	Eso es un acumulado.
	
	Por que escribir el frame explicitamente:
	----------------------------------------
	Cuando hay ORDER BY dentro del OVER, SQLite asume automaticamente ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW. 
	Pero otros motores (BigQuery, Snowflake) pueden tener defaults distintos. 
	Es buena practica escribirlo explicitamente para que tu query funcione igual en cualquier motor.
	
	Resultado esperado:
	Ana: mes 1 = 1200, 
	     mes 2 = 2700,
	     mes 3 = 3800, 
	     mes 4 = 5600. Cada fila muestra el total acumulado hasta ese mes.    
  
*/

SELECT
  vendedor,
  mes,
  monto,
  SUM(monto) OVER (
    PARTITION BY vendedor
    ORDER BY mes
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS monto_acumulado
FROM ventas;


/*
5. Muestra el monto del mes anterior y el mes siguiente para cada vendedor (Nivel 5 — LAG y LEAD). 

Que hace cada parte:

	LAG(monto, 1) mira hacia atras 1 fila dentro de la ventana. 	
	Para la fila del mes 2 de Ana, LAG devuelve el monto del mes 1 de Ana. 
	Para el mes 1 (la primera fila del grupo) no hay fila anterior, entonces devuelve NULL.
	      
	      
	LEAD(monto, 1) hace lo contrario: mira hacia adelante 1 fila. Para el mes 3 de Ana, 
	LEAD devuelve el monto del mes 4. Para el mes 4 (la ultima fila) devuelve NULL.
	
	El numero entre parentesis es cuantas filas saltar.
		LAG(monto, 2) miraria 2 filas atras. 
		LAG(monto, 1) es el caso mas comun.
	 
	monto - LAG(monto, 1) OVER (...) es la variacion respecto al mes anterior. 
	Si Ana tuvo 1200 en mes 1 y 1500 en mes 2, la variacion en mes 2 es +300. Puedes hacer esto sin ningun JOIN, solo con LAG.
	
	Por que es tan util:
	-------------------
	Antes de las window functions, comparar una fila con la anterior requeria un self-JOIN (unir la tabla consigo misma). 
	Con LAG/LEAD lo haces en una sola linea. Es mas legible, mas rapido, y menos propenso a errores.
	
	Resultado esperado:
	-------------------
	Mes 1 de cada vendedor tendra NULL en mes_anterior (no hay fila previa).
	Mes 4 tendra NULL en mes_siguiente. La columna variacion te dira si cada vendedor subio o bajo respecto al mes anterior.
 
 */
SELECT
  vendedor,
  mes,
  monto,
  LAG(monto, 1) OVER (PARTITION BY vendedor ORDER BY mes) AS mes_anterior,
  LEAD(monto, 1) OVER (PARTITION BY vendedor ORDER BY mes) AS mes_siguiente,
  monto - LAG(monto, 1) OVER (PARTITION BY vendedor ORDER BY mes) AS variacion
FROM ventas; 


/*
6. Calcula el promedio de ventas del mes actual y el anterior, por vendedor (Nivel 6 — Media móvil de 2 meses)

Que hace cada parte:
--------------------

AVG(monto) calcula el promedio. Nada nuevo.

ROWS BETWEEN 1 PRECEDING AND CURRENT ROW es el frame clave. Le dice a SQL: para cada fila, incluye
solo la fila anterior y la fila actual en el calculo.Eso significa:

	• Mes 1: solo tiene el mes 1 (no hay mes anterior) → promedio = monto del mes 1
	• Mes 2: promedio del mes 1 y mes 2
	• Mes 3: promedio del mes 2 y mes 3 (el mes 1 ya no entra)
	• Mes 4: promedio del mes 3 y mes 4

La ventana se mueve a medida que avanza por las filas. Por eso se llama media movil.
Comparacion de frames:

	-- Acumulado total (desde el inicio):
	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
	
	-- Media movil de 2 meses (actual + 1 anterior):
	ROWS BETWEEN 1 PRECEDING AND CURRENT ROW
	
	-- Media movil de 3 meses (actual + 2 anteriores):
	ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
	
	-- Total del grupo completo (sin acumular):
	ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
	
Para que sirve en la practica:
------------------------------
	Las medias moviles suavizan fluctuaciones. Si las ventas de un dia fueron muy altas por 
	un evento especial, la media movil lo amortigua y te muestra la tendencia real. Es muy
	usada en analisis financiero, metricas de producto y reportes de negocio.
*/
SELECT
  vendedor,
  mes,
  monto,
  AVG(monto) OVER (
    PARTITION BY vendedor
    ORDER BY mes
    ROWS BETWEEN 1 PRECEDING AND CURRENT ROW
    --ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) AS media_movil_2m
FROM ventas;


/*
7. Divide a los vendedores en 4 grupos según su monto, dentro de cada región (Nivel 7 — NTILE (cuartiles)).

Que hace cada parte:
--------------------

- NTILE(4) divide las filas de cada ventana en 4 grupos de igual tamano y asigna un numero del 1 al 4.  
  El grupo 1 tiene los valores mas bajos, el grupo 4 los mas altos.

	Si tienes 8 filas en la region Norte y usas NTILE(4), cada grupo tendra 2 filas. 
	Las 2 filas con menor monto reciben cuartil 1, las siguientes 2 reciben cuartil 2, y asi.
 
- PARTITION BY region aplica el NTILE dentro de cada region. 
  Las regiones Norte y Sur se calculan por separado.

- ORDER BY monto define como se ordenan las filas antes de repartirlas en grupos.
  ORDER BY monto ASC, cuartil 1 = los que menos vendieron.
	                  cuartil 4 = los que mas vendieron.

Cuando usar NTILE:
------------------
Es util para segmentar. Por ejemplo: identificar el 25% de clientes que mas compran (cuartil 4), o 
los vendedores en el bottom 25% para planes de mejora. 

Puedes usar cualquier numero: NTILE(10) crea deciles, NTILE(100) crea percentiles.

Resultado esperado:
-------------------
En la region Norte hay 8 filas. Veras como los montos de Diana y Bob (los mas bajos) quedan en cuartil 1 y 2, y
los de Carlos (los mas altos) en cuartil 4. Algunos meses de Ana quedaran en cuartil 2 o 3. 
 */

SELECT
  vendedor,
  region,
  mes,
  monto,
  NTILE(4) OVER (PARTITION BY region ORDER BY monto) AS cuartil
FROM ventas;


/* 
8. Para cada venta, muestra cuál fue el mejor y el peor mes del mismo vendedor (Nivel 8 — FIRST_VALUE y LAST_VALUE).

Que hace cada parte:
--------------------
	- FIRST_VALUE(monto) devuelve el valor de la primera fila dentro de la ventana. 
	  Con ORDER BY monto DESC, la primera fila es la de mayor monto. 
			-> Entonces FIRST_VALUE te da el mejor mes del vendedor, repetido en cada fila.


	- LAST_VALUE(monto) devuelve el valor de la ultima fila de la ventana. 
	  Con ORDER BY monto DESC, la ultima fila es la de menor monto.


El error clasico con LAST_VALUE — muy importante:
------------------------------------------------
Sin el frame explicito, LAST_VALUE NO funciona como esperas. El frame default cuando hay ORDER BY es 
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW. Eso significa que para cada fila, la "ultima" fila de la ventana es
la fila actual misma. 

LAST_VALUE te devolveria el monto de la fila actual, no el peor mes.

Por eso necesitas forzar el frame a ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING:
ahora la ventana siempre incluye todas las filas del grupo, y LAST_VALUE puede ver hasta el final.

FIRST_VALUE no tiene este problema porque la primera fila siempre esta visible, pero igual es buena practica escribir el frame explicitamente.

Resultado esperado:
-------------------
Para Ana: mejor_mes = 1800 (mes 4) y peor_mes = 1100 (mes 3), repetidos en las 4 filas de Ana. 
Puedes ver de un vistazo el rango de cada vendedor sin necesidad de un subquery.
 
*/

SELECT
  vendedor,
  mes,
  monto,
  FIRST_VALUE(monto) OVER (
    PARTITION BY vendedor ORDER BY monto DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) AS mejor_mes,
  LAST_VALUE(monto) OVER (
    PARTITION BY vendedor ORDER BY monto DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) AS peor_mes
FROM ventas;



/*
 
9. Calcula qué porcentaje representa cada venta sobre el total de su región (Nivel 9 — Porcentaje sobre el total del grupo).

Que hace cada parte:
--------------------
- SUM(monto) OVER (PARTITION BY region) 
  
  	- Sin ORDER BY calcula el total de toda la region y lo repite en cada fila.

  	- No es un acumulado, es el total completo del grupo visible desde cada fila.

    - Eso es posible porque sin ORDER BY, el frame default incluye todas las filas del grupo (no solo las anteriores). 

    - Cada fila ve el mismo total de su region.


- Monto * 100.0 / SUM(monto) OVER (...): Divide el monto de cada fila entre el total de su region y lo multiplica por 100. 
                                         Eso es el porcentaje que esa venta representa.                                        
                                         
- ROUND(..., 2) redondea a 2 decimales. El 100.0 (con decimales) es importante: en SQLite, 100 / 3 da 33 (division entera), pero 100.0 / 3 da 33.33.

Por que es poderoso:
--------------------
Sin window functions, esto requeriria un subquery o un JOIN:
 
 */

SELECT
  vendedor,
  region,
  mes,
  monto,
  ROUND(
    monto * 100.0 / SUM(monto) OVER (PARTITION BY region),
    2
  ) AS pct_region
FROM ventas;


--------------------------------------------------------------------------------------------------------
-------------------------------------------------- RETOS -----------------------------------------------
--------------------------------------------------------------------------------------------------------

/*
 Reto 1

Usando la tabla ventas, escribe una query que muestre el mejor mes de cada vendedor — es decir, el mes en que más vendió. 

Si hay empate, muestra cualquiera de los dos.

El resultado debe tener exactamente 4 filas (una por vendedor) con estas columnas:

vendedor	mes	monto
Ana	        ?	?
Bob	        ?   ?
Carlos	    ?	?
Diana	    ?	?

Pistas conceptuales (sin código):

Necesitas numerar las ventas de cada vendedor de mayor a menor
Luego filtrar solo la numero 1
En SQL no puedes filtrar directamente por una window function en el WHERE — tienes que envolverla en algo
*/


with rnk_ventas AS (
	SELECT
	  vendedor,
	  region,
	  mes,
	  monto,
	  ROW_NUMBER() over(partition by vendedor order by monto desc) as rnk_ventas  
	FROM ventas
)
select * from rnk_ventas
where rnk_ventas = 1;


/*
 Reto 2
Usando la tabla ventas, escribe una query que muestre para cada vendedor, mes a mes, cuánto creció 
o decreció respecto al mes anterior, y además 
una columna que diga si fue ‘subio’, ‘bajo’ o ‘igual’.

El resultado debe tener estas columnas:

vendedor	mes		monto	variacion	tendencia
Ana	1		    1200   	NULL      	NULL
Ana	2		    1500		300			subio
Ana	3		    1100	    -400			bajo
...	...	...	...	...

Pistas conceptuales:

Para la variación necesitas comparar cada fila con la anterior del mismo vendedor
Para la columna tendencia necesitas lógica condicional — hay una cláusula SQL para eso
El mes 1 de cada vendedor no tiene mes anterior, así que variación y tendencia serán NULL

Cuando la tengas, la revisamos. 
*/
WITH variacion as (
	SELECT
	  vendedor,
	  region,
	  mes,
	  monto,
	  (monto - LAG(monto, 1) over(partition by vendedor order by mes ASC)) as cal_variacion
	FROM ventas
)
SELECT *,
	CASE 
		  WHEN cal_variacion > 0 THEN 'subio'
		  WHEN cal_variacion < 0 THEN 'bajo'
		  WHEN cal_variacion = 0 THEN 'igual'
		  ELSE NULL   
	END AS tendencia
FROM variacion;


/*
 Reto 3
Usando la tabla ventas, escribe una query que muestre para cada vendedor su acumulado de ventas mes a mes, 
y además una columna que indique qué porcentaje representa ese 
acumulado sobre el total de ventas de su región.

El resultado debe tener estas columnas:

vendedor 	region	mes	monto	acumulado	pct_acumulado_vs_region
Ana			Norte	1	1200	    1200			11.5%
Ana			Norte	2	1500	    2700			25.9%
Ana			Norte	3	1100	    3800			36.5%
...	...	...	...	...	...

Pistas conceptuales:

- El acumulado ya lo practicaste en el Nivel 4 — es SUM con un frame
- El total de la región es un SUM sin ORDER BY que ya practicaste en el Nivel 9
- Necesitas dos ventanas distintas en la misma query
- El porcentaje es acumulado dividido entre el total de la región, multiplicado por 100

Este reto combina dos window functions con ventanas diferentes. Cuando lo tengas, lo revisamos.  
*/

with tbl_acum as (
	SELECT
  	vendedor,
  	region,
  	mes,
  	monto,
  	SUM(monto) OVER(partition by vendedor 
	  	order by mes asc
	  	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  	) acumulado    	
	FROM ventas
), tbl_total_ventas as (
	SELECT
		region,
		SUM(monto) as total_ventas
	FROM ventas 
	GROUP BY region 
)
SELECT tac.*,
	   ROUND(tac.acumulado/ttv.total_ventas , 2)  as pct_acumulado_vs_region    
FROM tbl_acum tac
inner join tbl_total_ventas ttv
 on tac.region = ttv.region;


-- v2
WITH tbl_acum AS (
  SELECT
    vendedor,
    region,
    mes,
    monto,
    SUM(monto) OVER (
      PARTITION BY vendedor
      ORDER BY mes
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS acumulado,
    SUM(monto) OVER (PARTITION BY region) AS total_region
  FROM ventas
)
SELECT
  vendedor, region, mes, monto, acumulado,
  ROUND(acumulado * 100.0 / total_region, 1) AS pct_acumulado_vs_region
FROM tbl_acum;

/*
 Reto 4

Usando la tabla ventas, escribe una query que muestre los 2 mejores vendedores 
de cada región basándose en su venta total (suma de los 4 meses).

El resultado debe tener estas columnas:
-----------------------------------------------
	region	vendedor		total_vendido	puesto
	Norte	Carlos		7700				1
	Norte	Ana			5600				2
	Sur		Bob			5000				1
	Sur		Diana		4000				2

Pistas conceptuales:
--------------------
- Primero necesitas el total vendido por cada vendedor — eso requiere agrupar
- Luego rankear dentro de cada región
- Luego filtrar los 2 primeros de cada región
- Vas a necesitar más de una CTE encadenada

Este reto combina GROUP BY tradicional con window functions. 
Son herramientas que se complementan, no se reemplazan. Cuando lo tengas, lo revisamos. 
 */
 
WITH tbl_totals AS (
  SELECT
    vendedor,
    region,
    SUM(monto) AS total_vendido   -- GROUP BY aqui, no window function
  FROM ventas
  GROUP BY vendedor, region
),
tbl_ranked AS (
  SELECT
    region,
    vendedor,
    total_vendido,
    DENSE_RANK() OVER (PARTITION BY region ORDER BY total_vendido DESC) AS puesto
  FROM tbl_totals
)
SELECT *
FROM tbl_ranked
WHERE puesto <= 2;


/*
Reto 5

Este es el más difícil hasta ahora. Usando la tabla ventas, escribe una 
query que muestre para cada vendedor y mes, las siguientes columnas:

vendedor	 mes		monto	media_movil_3m	diferencia_vs_media
Ana		 1		1200		1200.0			0.0
Ana		 2		1500		1350.0			150.0
Ana		 3		1100		1266.7			-166.7
Ana		 4		1800		1466.7			333.3
...	...	...	...	...

Donde:
------
media_movil_3m es el promedio del mes actual y los 2 meses anteriores del mismo vendedor
diferencia_vs_media es cuánto se alejó ese mes de su propia media móvil 
(positivo = vendió más de lo esperado, negativo = menos)

Pistas conceptuales:
--------------------
-La media móvil de 3 meses usa un frame específico — revisa el Nivel 6 de la guía
-La diferencia es simplemente monto menos la media móvil
-Ojo con el redondeo — usa ROUND(..., 1)
-No necesitas CTE para esto, puede ir todo en un solo SELECT
 */

WITH tbl_media_movil_3m as (
	SELECT
	  vendedor,
	  mes,
	  monto,
	  ROUND(AVG(monto) OVER (
	    PARTITION BY vendedor
	    ORDER BY mes
	    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
	  ), 1) AS media_movil_3m
	FROM ventas
)
SELECT vendedor,
	   mes,
	   monto,
	   media_movil_3m,
	   (monto - media_movil_3m) AS  diferencia_vs_media
FROM tbl_media_movil_3m;


/*
Reto 6
------
Este combina todo lo que has aprendido. Usando la tabla ventas, 
escribe una query que genere un reporte ejecutivo por vendedor con las siguientes columnas:

vendedor			region	total_vendido	rank_global	 mejor_mes	peor_mes 	variacion_mejor_vs_peor
-----------------------------------------------------------------------------------------------------
Carlos			Norte	7700				1		 	 2200		1600			600
Ana				Norte	5600				2			 1800		1100			700
Bob				Sur		5000				3	     	 1700		900			800
Diana			Sur		4000				4	     	 1200		800			400

Donde:

- total_vendido — suma de los 4 meses
- rank_global — posición del vendedor entre todos, de mayor a menor total
- mejor_mes — el monto más alto que tuvo en cualquier mes
- peor_mes — el monto más bajo que tuvo en cualquier mes
- variacion_mejor_vs_peor — diferencia entre su mejor y peor mes

Pistas conceptuales:

- Necesitas agregar primero con GROUP BY para obtener una fila por vendedor
- Sobre esa agregación aplicas las window functions
- mejor_mes y peor_mes no son window functions — son funciones de agregación normales dentro del GROUP BY
- rank_global sí es una window function, aplicada después

Sin CTEs no puedes hacer esto — necesitarás al menos una. Cuando lo tengas, lo revisamos. 
 */

with tbl_total_ventas AS 
(
	SELECT 
		vendedor	,	
		region,
		sum(monto) as total_vendido
		--rank_global,
		--mejor_mes
		--peor_mes,
		--variacion_mejor_vs_peor
	FROM ventas
	GROUP BY 1,2
),
tbl_mejor_pero_mes as (
	SELECT 
	   ttv.vendedor,	
	   ttv.region,
	   v.mes,
	   v.monto,
	   ttv.total_vendido 
	from ventas v
	inner join tbl_total_ventas ttv
		on v.vendedor  = ttv.vendedor  
)
select * from tbl_mejor_pero_mes;


SELECT vendedor,	
	   region,
	   total_vendido,
	   DENSE_RANK() OVER (ORDER BY total_vendido DESC) AS rank_global
FROM tbl_total_ventas;





-----------
-- delta tables

-- Time travel: leer el pasado
SELECT * FROM ventas VERSION AS OF 12;
SELECT * FROM ventas TIMESTAMP AS OF '2026-11-01';

-- Ver todo el historial de la tabla
DESCRIBE HISTORY ventas;

-- Deshacer un desastre
RESTORE TABLE ventas TO VERSION AS OF 11;

-- MERGE: upsert. Actualiza lo que existe, inserta lo nuevo.
MERGE INTO ventas t
USING nuevas s ON t.id = s.id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;

-- Compactar archivos pequeños y ordenar por columna de filtro
OPTIMIZE ventas ZORDER BY (cliente_id);

-- Borrar físicamente los archivos retirados de hace +7 días
VACUUM ventas RETAIN 168 HOURS;

-----------------
Checklist mental para "mi job está lento"
Abrir la Spark UI y encontrar el stage que consume el tiempo.
Mirar la distribución de duración de las tasks: si una domina, es skew.
Contar los shuffles: ¿se puede convertir algún join en broadcast?
Revisar el tamaño y número de archivos: ¿hace falta OPTIMIZE?
Comprobar que los filtros se empujan a la lectura y que hay partition pruning.
Verificar que no hay UDFs de Python en el camino caliente.
Comprobar spill a disco en la UI: si lo hay, faltan particiones o memoria.
Solo al final: agrandar el cluster. Escalar hardware antes de 
arreglar el plan es caro e inútil.

-------------------------
Las reglas memorizables: 

Un job por acción; 
un stage nuevo por cada shuffle;
una task por partición dentro del stage.
Las tasks de un stage son el mismo código sobre datos distintos.

PARTITION: 128 MB a 1 GB por partición.