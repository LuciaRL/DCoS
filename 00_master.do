/* -----------------------------------------------------------------------------

     WFP - Policy and Programme Division - Analysis & Trends Service 
		   Economic and Market Analysis Unit 
		   
     CONTACT: Lucia Latino 
			  lucia.latino@wfp.org
			  Latino@Economia.uniroma2.it
                    
     AIM: road map for the estimation of the Dietary Cost Score (DCoS)
		and the Dietary Cost Severity Score (DCoS2)
	 
     This version: November 30, 2016

----------------------------------------------------------------------------- */


*	Clear environment and set Stata working parameters
	clear all
	set more off
	set max_memory ., perm
	set matsize 1000, perm
	capture log close

* Set folder path

	if c(username)=="lucia.latino"{
		global path "C:\Users\lucia.latino\Documents\2.Market_team\DCoS\data"
		}

		else {
			global path "/Users/Lucia/Dropbox/WFP/market_team/DCoS/data"
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
	01_vam.do
	
	AIM:  - get data for the estimation of the cost of food basket from vam db
	note: lines to be checked are about ad hoc fixies (lines 114-122)
		and the date for the label of GIEWS dataset (line 408)
--------------------------------------------------*/
	do 01_vam.do	

/*-----------------------------------------------------------------------------
	02_giews.do
	
	AIM:  - get data for the estimation of the cost of food basket from giews
	note: line to be checked is about the date for dataset's label (line 217)
-----------------------------------------------------------------------------*/
	do 02_giews.do	

/*-------------------------------------------------
	03_cleaning.do
	
	AIM:  - merge datasets, clean price series, generate national average and 
			run 03b_priority.do (AIM: set  priority for price series within 
			the same fao_fct_name)
	note: lines to be checked are 67, 71, 107-108, 124, 241.
		If line 241 is not needed to generate exceptions, then code lines 240-455 
		in 03b_priority.do are not needed
--------------------------------------------------*/
	do 03_cleaning.do	
	
/*-------------------------------------------------
	04_basket.do
	
	AIM:  - compute the cost of food basket 
		note: lines to be checked are loops 51-100
--------------------------------------------------*/
	do 04_basket.do	
	
/*-------------------------------------------------
	05_seasonal_index.do
	
	AIM:  - compute the seasonal index for the
			cost of food basket 
--------------------------------------------------*/
	do 05_seasonal_index.do	
	
/*-----------------------------------------------------------------------------
	06_DCoS.do
	
	AIM:  - build the monthly and the forward-looking score
-----------------------------------------------------------------------------*/
	do 06_DCoS.do		
		
	
* Great! You made it!

exit
