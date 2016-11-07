/* -----------------------------------------------------------------------------

     WFP - Policy and Programme Division - Analysis & Trends Service 
		   Economic and Market Analysis Unit 
		   
     CONTACT: Lucia Latino 
			  lucia.latino@wfp.org
			  Latino@Economia.uniroma2.it
                    
	 AIM:  - get data for the estimation of the cost of food basket 
			from GIEWS dataset
			
     This version: November 4, 2016

----------------------------------------------------------------------------- */


*** Clear environment 
	clear
	set more off
	set maxvar 20000
	
********************************	
*	 	get GIEWS data 		   *
********************************	
	clear
	import excel using $path/input/FPMA_Price_Retail.xlsx, cellrange(A1) firstrow
	replace PriceLCKg=PriceLCLM if PriceLCKg==. & PriceLCLM!=. & OriginalMeasure=="Liter"
	replace PriceLCKg=PriceUSDKg if Country=="Nicaragua"
	drop if PriceLCKg==. & Price_RealLCKg==. & PriceUSDKg==. & PriceLCLM==.
	tempfile retail
	save `retail'
	
	clear 
	import excel using $path/input/FPMA_Price_Wholesale.xlsx, cellrange(A1) firstrow
	append using `retail'
	
* rename/recode variables to match with WFP dataset
	gen pt=14 if MarketType=="Wholesale"
	replace pt=15 if MarketType=="Retail"
	rename Country adm0_name
	gen mkt_name=location 
	rename Commodity cm_name
	rename Source source
	gen price_kg_FAO=PriceLCKg if pt==15
	replace price_kg_FAO=PriceLCTonne/1000 if pt==14
	replace price_kg_FAO=Price_USDTonne/1000 if pt==14 & adm0_name=="Nicaragua"
	replace Currency="US Dollar" if adm0_name=="Nicaragua"
	gen um_name="KG"
	
	gen month=month(Date)
	gen year=year(Date)
	gen time= mdy(month, 1, year)
	format time %tdMon-yy

	tempfile data_giews
	save `data_giews'

* recover the market and country id from the Big table
	import excel  $path/input/BigTable_Tool.xlsx, sheet("fao_mkt") cellrange(A1) firstrow clear
	drop if mkt_name ==""
	keep mkt_name mkt_id adm0_name adm0_id
	
	merge 1:m adm0_name mkt_name using `data_giews'
	capture assert _m!=2
		if _rc==0 {
		}
		else display as error "New markets! Update "fao_mkt" in BigTable.xlsx and run 01_data.do"
	
	drop if _merge==1
	drop if adm0_name=="" & pr==.
	assert _merge!=2 
	
*** average the price for markets Managua and Managua (oriental) in Nicaragua as they correspond to the same market id
	bys cm_name month year pt Currency: egen temp=mean(price_kg_FAO) if ///
		adm0_name=="Nicaragua" & (mkt_name=="Managua" | mkt_name=="Managua (oriental)")
	replace price_kg_FAO=temp  if adm0_name=="Nicaragua" & (mkt_name=="Managua" | mkt_name=="Managua (oriental)")
	duplicates tag adm0_name mkt_id cm_name month year pt Currency , gen (dup)
	egen tag=tag(adm0_name mkt_id cm_name month year pt Currency dup) if dup==1
	drop if tag
	replace mkt_name="Managua" if mkt_name=="Managua (oriental)"
	drop temp dup tag
	
	keep adm0_id adm0_name mkt_name mkt_id pt time cm_name Currency price_kg_FAO um_name PriceLCTonne source PriceLCKg month year time
	duplicates drop
	
	tempfile data_giews
	save `data_giews'
	
* recover the commodity id from the MM big table
	import excel $path/input/BigTable_Tool.xlsx, sheet("Master_List") cellrange(A3) firstrow clear
	drop if ext_data==0
	keep cm_name cm_id
	
	merge m:m cm_name using `data_giews'
	capture assert _m!=2 | cm_name=="Antelope (meat, smoked)" | cm_name=="Gazelle (meat, smoked)" ///
				| cm_name=="Soya beans (imported)"
		if _rc==0 {
		}
		else display as error "New ommodity! Update BigTable and run 01_data.do"
		
	drop if cm_id==. 
	drop if price_kg==.
	rename cm_name cm_name_FAO
	drop _merge

* coding currency	
	gen cur_name= "AFN" if Currency=="Afghani"
	replace cur_name= "DZD" if Currency=="Algerian Dinar"
	replace cur_name= "AOA" if Currency=="Kwanza"
	replace cur_name= "ARS" if Currency=="Argentine Peso"
	replace cur_name= "AMD" if Currency=="Armenian Dram"
	replace cur_name= "AZN" if Currency=="Manat"
	replace cur_name= "BDT" if Currency=="Taka"
	replace cur_name= "BYR" if Currency=="Belarussian Ruble"
	replace cur_name= "BTN" if Currency=="Ngultrum"
	replace cur_name= "BOB" if Currency=="Boliviano"
	replace cur_name= "BRL" if Currency=="Brazilian Real"
	replace cur_name= "BIF" if Currency=="Burundi Franc"
	replace cur_name= "KHR" if Currency=="Riel"
	replace cur_name= "DJF"	if Currency=="Djibouti Franc"
	replace cur_name= "XAF" if Currency=="CFA Franc" & (adm0_name=="Cameroon" | adm0_name=="Central African Republic" |  ///
							  adm0_name=="Chad" | adm0_name=="Gabon")
	replace cur_name= "CVE" if Currency=="Cabo Verde Escudo"
	replace cur_name= "CLP" if Currency=="Chilean Peso"	
	replace cur_name= "CNY" if Currency=="Yuan Renminbi"
	replace cur_name= "COP" if Currency=="Colombian Peso"
	replace cur_name= "CRC" if Currency=="Costa Rican Colon"
	replace cur_name= "CDF" if Currency=="Franc Congolais"
	replace cur_name= "DOP" if Currency=="Dominican Peso"
	replace cur_name= "EGP" if Currency=="Egyptian Pound"
	replace cur_name= "USD" if Currency=="US Dollar"
	replace cur_name= "ERN" if Currency=="Nakfa"
	replace cur_name= "ETB" if Currency=="Ethiopian Birr"
	replace cur_name= "GEL" if Currency=="Lari"
	replace cur_name= "GHS" if Currency=="Ghana Cedi"
	replace cur_name= "GTQ" if Currency=="Quetzal"
	replace cur_name= "GNF" if Currency=="Guinea Franc"
	replace cur_name= "HTG" if Currency=="Gourde"
	replace cur_name= "HNL" if Currency=="Lempira"
	replace cur_name= "INR" if Currency=="Indian Rupee"
	replace cur_name= "IDR" if Currency=="Rupiah"
	replace cur_name= "NIS" if Currency=="New Israeli Sheqel"
	replace cur_name= "KES" if Currency=="Kenyan Shilling"
	replace cur_name= "KGS" if Currency=="Som"
	replace cur_name= "LAK" if Currency=="Kip"
	replace cur_name= "LSL" if Currency=="Loti"
	replace cur_name= "LRD" if Currency=="Liberian Dollar"
	replace cur_name= "MGA" if Currency=="Malagasy Ariary"
	replace cur_name= "MWK" if Currency=="Kwacha" & adm0_name=="Malawi"
	replace cur_name= "XOF" if Currency=="CFA Franc" & (adm0_name=="Mali" | adm0_name=="Benin" | adm0_name=="Burkina Faso" | ///
							adm0_name=="Niger" | adm0_name=="Senegal" | adm0_name=="Togo")  
	replace cur_name= "MRO" if Currency=="Ouguiya"
	replace cur_name= "MXN" if Currency=="Mexican Peso"
	replace cur_name= "MDL" if Currency=="Moldovan Leu"
	replace cur_name= "MNT" if Currency=="Tugrik"
	replace cur_name= "MAD" if Currency=="Moroccan Dirham"
	replace cur_name= "MZN" if Currency=="Metical"
	replace cur_name= "MMK" if Currency=="Kyat"
	replace cur_name= "NAD" if Currency=="Namibia Dollar"
	replace cur_name= "NPR" if Currency=="Nepalese Rupee"
	replace cur_name= "NIO" if Currency=="Cordoba Oro"
	replace cur_name= "NGN" if Currency=="Naira"
	replace cur_name= "PKR" if Currency=="Pakistan Rupee"
	replace cur_name= "PAB" if Currency=="Balboa"
	replace cur_name= "PYG" if Currency=="Guarani"
	replace cur_name= "PEN" if Currency=="Nuevo Sol"
	replace cur_name= "PHP" if Currency=="Philippine Peso"
	replace cur_name= "RUB" if Currency=="Russian Ruble"
	replace cur_name= "RWF" if Currency=="Rwanda Franc"
	replace cur_name= "SLL" if Currency=="Leone"
	replace cur_name= "SOS" if Currency=="Somali Shilling"
	replace cur_name= "ZAR" if Currency=="Rand"
	replace cur_name= "LKR" if Currency=="Sri Lanka Rupee"
	replace cur_name= "SDG" if Currency=="Sudanese Pound"
	replace cur_name= "TJS" if Currency=="Somoni"
	replace cur_name= "THB" if Currency=="Baht"
	replace cur_name= "TND" if Currency=="Tunisian Dinar"
	replace cur_name= "UGX" if Currency=="Uganda Shilling"
	replace cur_name= "UAH" if Currency=="Hryvnia"
	replace cur_name= "TZS" if Currency=="Tanzanian Shilling"
	replace cur_name= "UYU" if Currency=="Peso Uruguayo"
	replace cur_name= "UZS" if Currency=="Uzbekistan Sum"
	replace cur_name= "VND" if Currency=="Dong"
	replace cur_name= "ZMW" if Currency=="Kwacha" & adm0_name=="Zambia"
	replace cur_name= "EUR" if Currency=="Euro"
	replace cur_name= "WST" if Currency=="Tala"
	replace cur_name= "SZL" if Currency=="Lilangeni"
	replace cur_name= "SAR" if Currency=="Saudi Riyal"
	replace cur_name= "YER" if Currency=="Yemeni Rial"

	tempfile temp
	save `temp'
	
*** get currency id	
	set odbcdriver unicode
	odbc list
	global db  "DRIVER={SQL Server};SERVER=wfpromsqlp02;DATABASE=MONITORING;UID=monitor_usr_ro ;PWD=M0n1R015;"
	
	odbc load, exec("SELECT * FROM currencies") conn("$db") clear
	tempfile currencies
	save `currencies'
		
	merge 1:m cur_name using `temp'

	replace cur_id=9904 if cur_name=="NGN"
	replace cur_id=9902 if cur_name=="PAB"
	replace cur_id=9917 if cur_name=="THB"
	replace cur_id=9921 if cur_name=="VND"
	replace cur_id=9903 if cur_name=="HNL"

	assert cur_id!=.
	drop if _merge==2
	drop _merge
	
	gen ext_data = 1
	order  adm0* mkt* month year cm* cur* pt price um_name source
	gsort adm0_name mkt_id cm_name -year -month
	label data "GIEWS Food Price database as at July 13, 2016"
	
	qui compress
	save $path/output/data_giews.dta, replace
