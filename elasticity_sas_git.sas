/* Importing prod_milk data */

proc import file="H:\PROJECTDATA\prod_milk.xls"
out=m1
replace
dbms=xls;
run; 
proc print data=m1(obs=10);run;
proc Freq ORDER=Freq; table PRODUCT_TYPE;run;
proc contents data=m1;run;
/* Importing Delivery Store Data */

data d3;
infile 'H:\PROJECTDATA\Delivery_Stores' firstobs=2 expandtabs MISSOVER;
input IRI_KEY 1-7 OU $ 9-10 EST_ACV 11-19 Market_Name $ 20-42 Open 42-49 Clsd 50-54 MskdName $ 55-63;
run;
proc print data = d3(OBS =10);RUN;

/* Importing Milk Groc  Data */
DATA mg; 
INFILE 'H:\PROJECTDATA\milk_groc_1114_1165' FIRSTOBS=2 expandtabs MISSOVER; 
INPUT IRI_KEY WEEK SY GE VEND ITEM UNITS DOLLARS F $ D PR; 
run;
   
proc print data=mg(obs=10);run;

/* UPC code generation GE1=GE z2. VEND1=VEND z5. ITEM1=ITEM z5.*/
/*put format*/
data mg_zero;
set mg;
zero_code_sy = put(SY, z2.);
zero_code_ge = put(GE, z2.);
zero_code_vend = put(VEND, z5.);
zero_code_item = put(ITEM, z5.);run;

proc print data=mg_zero (obs=10);run;

data mg_new;
set mg_zero;
UPC = CAT(zero_code_sy,"-",zero_code_ge,"-",zero_code_vend,"-",zero_code_item);
run;
proc print data=mg_new (obs=10);run;

data mg_final;
set mg_new;
KEEP IRI_KEY WEEK SY GE VEND ITEM UNITS DOLLARS F D PR UPC;
run;
proc print data=mg_final (obs=10);run;
proc contents data=mg_final;run;
/* Merging data */
PROC SORT Data=mg_final;
   BY IRI_KEY;run;
PROC SORT Data=d3;
   BY IRI_KEY;run;

DATA i1;
   MERGE mg_final(IN=aa) d3;
   IF aa;BY IRI_KEY;run;
PROC PRINT DATA=i1(obs=10);RUN;
/*calculating number of ounces and dropping few variables from data in prod_milk file*/
data m2;
set m1;
drop SY GE VEND ITEM;
oz =SUBSTR(L9,length(L9)-3,4);
size_oz = input(substr (oz, 1, length(oz)-2),2.);
run;
PROC PRINT DATA=m2(obs=10);RUN;
data m3;
set m2 (drop = oz L9);
rename L3= Group_Name L4 = Company L5 = Brand;
run;
PROC PRINT DATA=m3(obs=10);RUN;

PROC SORT Data=i1;
   BY UPC;run;
PROC SORT Data=m3;
   BY UPC;run;

DATA m4;
   MERGE i1(IN=bb) m3;
   IF bb;BY UPC;
   run;

PROC PRINT DATA=m4(obs=10);RUN;
/*creating price/ounce column*/
data master;
set m4;
price_oz = dollars/(units*size_oz);
run;
PROC PRINT DATA=master(obs=10);RUN;


PROC SORT Data=master;
   BY IRI_KEY;run;

PROC PRINT DATA=master(obs=10);RUN;
Proc contents data=master;run;

/*DESCRIPTIVE SUMMARY*/
proc freq data =master order=freq; table DOLLARS;run;
proc freq data =master order=freq; table DOLLARS;run;

/*Combining like brands together*/
data master_inter;
set master;
IF PRODUCT_TYPE="MILK";
if D = 1 or D = 2 then DS = 1; else DS = 0;
if F ne ('NONE') then FEATURE = 1; else FEATURE = 0;

data master_final;
set master_inter;
if Brand in ('LACTAID 100','LACTAID 70' ) then Brand='LACTAID';
if Brand in ('NESTLE NESQUIK')then Brand='NESTLE';
if Brand in ('DEANS','DEANS EASY', 
'DEANS CHOCO RIFFIC','DEANS CHUG SHAKE') then Brand = 'DEANS';
if Brand in ('HOOD', 'HOOD SIMPLY SMART', 'HOOD NUFORM','HOOD CHOCO GOOD') then Brand = 'HOOD';
if Brand in ('GARELICK FARMS', 'GARELICK FARMS KIDSMILK', 'GARELICK FARMS FITMILK',
'GARELICK FARMS SKIM AND MORE') then Brand = 'GARELICK FARMS';
if Brand not in('LACTAID','DEANS','HOOD','GARELICK FARMS','NESTLE') then Brand='OTHER';
run;
proc contents data=master_final;run;

PROC SORT Data=master_final;
   BY Brand;run;
proc means data =master_final; var DOLLARS ; by Brand ;run;
proc print data =master_final (obs=10) ;run;

LIBNAME cc'H:\PROJECTDATA\';
data master_final;
set cc.master_final;
run;

PROC SQL;
CREATE TABLE MARKET_DETAIL AS (
SELECT MARKET_NAME,MSKDNAME ,SUM(DOLLARS) AS GROSS_REV 
FROM master_final where OU='GR'
group by MARKET_NAME,MSKDNAME);
quit;
proc sort data=MARKET_DETAIL;BY GROSS_REV;RUN;
proc print data =MARKET_DETAIL;run;
proc sql;
select DISTINCT(BRAND) from master_final where MARKET_NAME='LOS ANGELES' AND MSKDNAME='Chain94';
QUIT;
PROC SQL;
CREATE TABLE WS AS(
SELECT UNITS,BRAND,FLAVOR_SCENT,TYPE_OF_MILK,PACKAGE,price_oz,DS,FEATURE,DOLLARS,VOL_EQ
FROM MASTER_FINAL
WHERE Brand='NESTLE');
QUIT;
proc sort data=WS;BY VOL_EQ;RUN;
proc print data =WS (obs=10);run;
data nestle_analysis;
set WS;
if FLAVOR_SCENT='BANANA' THEN FB=1; else FB=0;
if FLAVOR_SCENT='CHOCOLATE' THEN FC=1; else FC=0;
if TYPE_OF_MILK='REDUCED FAT' THEN TR=1; else TR=0;
if TYPE_OF_MILK='SKIM' THEN TS=1; else TS=0;
if PACKAGE='CARTON' THEN PKG=1 ;else PKG=0;
run;
proc print data =nestle_analysis (obs=10);run;

data nestle_analysis;
keep UNITS price_oz DS FEATURE DOLLARS PKG FB FC TR TS VOL_EQ;
set nestle_analysis;
run;
LIBNAME cc'H:\PROJECTDATA\';
data cc.nestle_analysis;
set nestle_analysis;
run;
LIBNAME cc'H:\PROJECTDATA\';
data nestle_analysis_test;
set cc.nestle_analysis;
run;


proc reg data = nestle_analysis;
model DOLLARS = UNITS price_oz DS FEATURE PKG FB FC TR TS VOL_EQ/STB vif collin;
run;
proc print data=nestle_analysis_test (obs=2);run;
Proc SurveySelect 
Data= nestle_analysis
Out= sample1
Method= SRS /* Selection of sampling method */ 
Sampsize= 80000 /* Selection of sample size */ 
Seed= 13571; Run;


PROC SYSLIN 2SLS SIMPLE data=sample1;
ENDOGENOUS DOLLARS price_oz;
INSTRUMENTS DS FEATURE PKG FB TR VOL_EQ;
MODEL DOLLARS = price_oz DS FEATURE PKG FB FC TR TS;
MODEL price_oz = DOLLARS PKG FB FC TR TS VOL_EQ;
RUN;


/*MODEL-2*/
data master_model2;
set master_inter;
if Brand in ('LACTAID 100','LACTAID 70' ) then Brand='LACTAID';
if Brand in ('NESTLE NESQUIK')then Brand='NESTLE';
if Brand in ('HOOD', 'HOOD SIMPLY SMART', 'HOOD NUFORM','HOOD CHOCO GOOD') then Brand = 'HOOD';
if Brand not in('LACTAID','HOOD','NESTLE') then Brand='OTHER';
run;

proc sql;
create table sales_data as 
select * from master_model2 a;
quit;
/*calculating gross_units*/
proc sql;
create table sales_data as
select a.*, b.gross_units
from sales_data a 
inner join (select IRI_KEY, week, Brand, sum(UNITS) as gross_units
			from sales_data
			group by IRI_KEY, week, Brand) b 
on a.IRI_KEY = b.IRI_KEY and a.week = b.week and a.Brand = b.Brand;
quit;
/*calculating weighted values*/
data sales_data;
retain IRI_KEY week Company Brand UPC price_oz wt_price_oz units gross_units PR wt_PR DS wt_DS F wt_Feature;
set sales_data;
wt_price_oz = price_oz*units/gross_units;
wt_PR= PR*units/gross_units;
wt_DS = DS*units/gross_units;
wt_Feature = FEATURE*units/gross_units;
format wt_PR 4.2 wt_DS 4.2 wt_Feature 4.2 price_oz 4.2 wt_price_oz 4.2;
run;
/*Calculating annual market share*/  
PROC SQL;
CREATE TABLE MILK_SHARE AS (
SELECT UPC,VOL_EQ ,100*SUM(DOLLARS)/(GROSS_REV) AS MKT_SHARE
FROM ( select  *, 1 as fg from  sales_data) as a inner join
(SELECT SUM(DOLLARS) AS GROSS_REV, 1 as flag FROM sales_data) as b
on a.fg = b.flag
GROUP BY UPC,VOL_EQ);
QUIT;

PROC SQL;
CREATE TABLE Sales_weighted AS (
SELECT IRI_KEY, WEEK ,BRAND, SUM(DOLLAR_SALES) AS SALES,
AVG(WTD_PRICE) AS AVG_PRICE_PCT ,
AVG(WTD_DS) AS AVG_DS_PCT,
AVG(WTD_FT) AS AVG_FT_PCT,
AVG(WTD_PR) AS AVG_PR_PCT
FROM (
SELECT IRI_KEY, WEEK,BRAND, A.UPC,A.VOL_EQ, SUM(DOLLARS) AS DOLLAR_SALES,
wt_price_oz*MKT_SHARE  AS WTD_PRICE, 
wt_ds*MKT_SHARE AS WTD_DS,
wt_Feature*MKT_SHARE AS WTD_FT,
wt_PR*MKT_SHARE AS WTD_PR

FROM sales_data A
INNER JOIN MILK_SHARE B
ON A.UPC = B.UPC
AND A.VOL_EQ = B.VOL_EQ
GROUP BY IRI_KEY, WEEK,BRAND, A.UPC,A.VOL_EQ)
GROUP BY IRI_KEY, WEEK,BRAND);
QUIT;
proc sql;
create table sales_brandwise as
select IRI_KEY, week, brand,
sum(wt_price_oz) as gross_wt_brand_price,
sum(wt_PR) as gross_PR_wt, 
sum(wt_DS) as gross_disp_wt, 
sum(wt_Feature) as gross_Feature_wt
from sales_data
group by IRI_KEY, week, brand
order by 1,2,3;
quit;
/*Quality check*/

proc sql;
select count (*) as count
from
( select distinct IRI_KEY, week, brand
	from  Sales_weighted
);
quit;
proc sql;
select count(*) as count
from
(
select IRI_KEY, week, brand
from Sales_weighted
);
quit;
/*selecting sales of all 3 brands */

data brand1 brand2 brand3 brand4;
set Sales_weighted;
if brand = 'HOOD' then output brand1;
else if brand = 'LACTAID' then output brand2;
else if brand = 'NESTLE' then output brand3;
else output brand4;
run;

proc sql;
create table all_brand_wt_price as
select
a.IRI_KEY, a.week,

a.AVG_PRICE_PCT as wt_price_brand1,
a.AVG_PR_PCT as PR_wt_brand1,
a.AVG_DS_PCT as disp_wt_brand1,
a.AVG_FT_PCT as Feature_wt_brand1,

b.AVG_PRICE_PCT as wt_price_brand2,
b.AVG_PR_PCT as PR_wt_brand2,
b.AVG_DS_PCT as disp_wt_brand2,
b.AVG_FT_PCT as Feature_wt_brand2,


c.AVG_PRICE_PCT as wt_price_brand3,
c.AVG_PR_PCT as PR_wt_brand3,
c.AVG_DS_PCT as disp_wt_brand3,
c.AVG_FT_PCT as Feature_wt_brand3,


d.AVG_PRICE_PCT as wt_price_brand4,
d.AVG_PR_PCT as PR_wt_brand4,
d.AVG_DS_PCT as disp_wt_brand4,
d.AVG_FT_PCT as Feature_wt_brand4

from brand1 a 
inner join brand2 b on a.IRI_KEY = b.IRI_KEY and a.week = b.week
inner join brand3 c on a.IRI_KEY = c.IRI_KEY and a.week = c.week
inner join brand4 d on a.IRI_KEY = d.IRI_KEY and a.week = d.week
order by a.IRI_KEY, a.week;
quit;
proc sql;
create table NESTLE_model2 as
select 
b.*,

b.wt_price_brand1*b.PR_wt_brand1 as price_PR1,
b.wt_price_brand2*b.PR_wt_brand1 as price_PR2,
b.wt_price_brand3*b.PR_wt_brand1 as price_PR3,
b.wt_price_brand4*b.PR_wt_brand1 as price_PR4,

b.wt_price_brand1*b.Feature_wt_brand1 as price_F1,
b.wt_price_brand2*b.Feature_wt_brand2 as price_F2,
b.wt_price_brand3*b.Feature_wt_brand3 as price_F3,
b.wt_price_brand4*b.Feature_wt_brand3 as price_F4,

b.PR_wt_brand1*b.Feature_wt_brand1 as PR_F1,
b.PR_wt_brand2*b.Feature_wt_brand2 as PR_F2,
b.PR_wt_brand3*b.Feature_wt_brand3 as PR_F3,
b.PR_wt_brand4*b.Feature_wt_brand3 as PR_F4,

case when a.gross_units is null then 0
else a.gross_units end as gross_units, a.sales as sales

from all_brand_wt_price b
inner join (select IRI_KEY, week, brand,sum(UNITS) as gross_units,sum(DOLLARS) as sales 
			from sales_data
			where brand = "NESTLE"
			group by IRI_KEY, week, brand ) a
on a.IRI_KEY = b.IRI_KEY and a.week = b.week
order by IRI_KEY, week;
quit;

PROC SQL;
SELECT week, sum(gross_units) as total_units , avg(wt_price_brand1) as avg_wt_price
from NESTLE_model2
group by week;
quit;


proc corr data = NESTLE_model2;
var gross_units sales;
run;
proc reg data = NESTLE_model2;
model gross_units =   wt_price_brand1 wt_price_brand2 wt_price_brand3 wt_price_brand4
					disp_wt_brand1 disp_wt_brand2 disp_wt_brand3 disp_wt_brand4
					Feature_wt_brand4
					PR_wt_brand2 PR_wt_brand4
					price_F1 price_F2 price_F3 price_F4
					PR_F1 PR_F2 PR_F3 PR_F4
					/vif collin ;
run;

proc panel data= NESTLE_model2;
model gross_units =  wt_price_brand1 wt_price_brand2 wt_price_brand3 wt_price_brand4
					disp_wt_brand1 disp_wt_brand2 disp_wt_brand3 disp_wt_brand4
					Feature_wt_brand4
					PR_wt_brand2 PR_wt_brand4
					price_PR1 price_PR2 price_PR3 price_PR4
					price_F1 price_F2 price_F3 price_F4
					/ fixtwo  vcomp=fb plots=none;
id IRI_KEY week;
run;

/*Computing means for price elasticity calculation*/

proc means data=NESTLE_model2;
var gross_units wt_price_brand1 wt_price_brand2 wt_price_brand3 wt_price_brand4 
	price_PR1 price_PR2 price_PR3 price_PR4
	price_F1 price_F2 price_F3 price_F4;
run;
