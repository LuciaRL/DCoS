/* -----------------------------------------------------------------------------

     WFP - Policy and Programme Division - Analysis & Trends Service 
		   Economic and Market Analysis Unit 
		   
     CONTACT: Lucia Latino 
			  lucia.latino@wfp.org
			  Latino@Economia.uniroma2.it
                    
     AIM: road map for the estimation of the Seasonal Food Expenditure Score (SFE)
		and the Severity of the Seasonal Food Expenditure Score (SFES)
	 
     This version: July 18, 2016

----------------------------------------------------------------------------- */


*	Clear environment and set Stata working parameters
	clear
	set more off
	set max_memory ., perm
	set matsize 1000, perm
	capture log close

* Set folder path

	if c(username)=="lucia.latino"{
		global path "C:\Users\lucia.latino\Documents\SFE\data"		
		}

		else {
			global path "/Users/Lucia/Dropbox/WFP/market_team/SFE/data"
			}
*	Note: 	new dta files are always saved in the folder $path/output/
*			original data are stored in the folder $path/input/
	
cd $path

/*-------------------------------------------------

	STEP ZERO
	
	(i) get updated data from GIEWS/FAO and save them in the input folder as: 
		FPMA_Price_Retail.xlsx
		FPMA_Price_Wholesale.xlsx
	(ii) the file BigTable_Tool, sheets "fao_mkt" and "Master_List" may need 
		updates if VAM and/or GIEWS have add new commodities, change codes, currency or unit of measure.
	(iii) updates exchange rate values for Somalia in BigTable_Tool, sheets "Somalia_ExchangeRate"	
	(iv) check that the list of countries in country.xlsx is complete
--------------------------------------------------*/


/*-------------------------------------------------

	01_data.do
	
	AIM:  - get data for the estimation 
			of the cost of food basket 
	note: lines to be checked are about ad hoc fixies (lines 116-125)
	
--------------------------------------------------*/

	do 01_data.do	


/*-------------------------------------------------

	02_cleaning.do
	
	AIM:  - clean price series and 
			generate national average
		note: lines to be checked are 129-130 and 143
--------------------------------------------------*/

	do 02_cleaning.do	
	

/*-------------------------------------------------

	03_basket.do
	
	AIM:  - compute the cost of food basket 
		note: lines to be checked are 26 and in loops 51-108

--------------------------------------------------*/

	do 03_basket.do	
	
	
/*-------------------------------------------------

	04_seasonal_index.do
	
	AIM:  - compute the seasonal index for the
			cost of food basket 
	
--------------------------------------------------*/

	do 04_seasonal_index.do	
	
	
/*-------------------------------------------------

	05_SFE.do
	
	AIM:  - build the monthly and 
		the forward-looking score
	
--------------------------------------------------*/

	do 05_SFE.do	
		
	
* Great! You made it!

exit
