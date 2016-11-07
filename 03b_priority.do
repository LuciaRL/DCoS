/* -----------------------------------------------------------------------------

     WFP - Policy and Programme Division - Analysis & Trends Service 
		   Economic and Market Analysis Unit 
		   
     CONTACT: Lucia Latino 
			  lucia.latino@wfp.org
			  Latino@Economia.uniroma2.it
      
	 AIM: Set  priority for price series within the same fao_fct_name
     
     This version: November 4, 2016

----------------------------------------------------------------------------- */


	drop series
	egen series = group (adm0_id cm_id pt)
	sort series time
	
	gen gap=1-(data_count/month_cover)
		
	bys adm0_id fao_fct_name: egen longer=max(month_cover)
	bys adm0_id fao_fct_name: egen complete=min(gap)

	gen priority=.
	
** CRITERIA 1: the longest and more complete series	
	gen criteria=.
	gen pick=(month_cover==longer & month_cover>=60 & gap==complete & series_m==12)	
	replace criteria=1 if pick==1
	egen flag=tag(adm0_id cm_id pt)
	bys adm0_id fao_fct_name: egen check=total(pick) if flag
	bys adm0_id fao_fct_name: egen check_sum=total(pick)
	replace priority=1 if pick==1 // highest priority is for the longest and more complete series
	
	sum check  // when first criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
	local mul_series=r(max)
	
	if `mul_series'>1 & `mul_series'!=. {
		tempvar mean   
		bys series: egen `mean'=mean(price) if t>date_end-60
		bys series: egen mean=mean(`mean')
		bys adm0_id fao_fct_name: egen equal_p=mean(check) 
		sum equal_p
		local check=r(max)
		local i=2
	
		while `i'<=`check' {
			bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i'
			replace priority=`i' if mean!=. & expensive!=. & mean==expensive & equal_p==`i'
			local g=`i'
			
			while `g'>2 {
				drop expensive
				bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i'
				replace priority=`g'-1 if mean==expensive & equal_p==`i'
				local g=`g'-1
			}
			drop expensive	
			local i=`i'+1
		}
	}
	

// apply second criteria for the series not satisfy first criteria but belong to the same group of other series satisfing the first criteria
	egen missing=rowmiss(priority)
	sum missing
	local p=r(max)
	if `p'==1 {
		replace pick=1 if check_sum!=0 & priority==. & (month_cover==longer & month_cover>=60 & series_m==12)
		replace criteria=1 if check_sum!=0 & priority==. & (month_cover==longer & month_cover>=60 & series_m==12)
		tempvar max_p
		bys adm0_id fao_fct_name: egen `max_p'=max(priority)
		bys adm0_id fao_fct_name: replace priority=`max_p'+1 if priority==. & check_sum!=0 & pick==1
	
		tempvar dup  // when second criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
		duplicates tag adm0_id fao_fct_name priority if pick==1 & flag==1, gen(`dup')
		bys adm0_id fao_fct_name: egen duplicates=mean(`dup') if criteria==2  & `dup'!=0
		sum `dup' 
		local mul_series=r(max)
		if `mul_series'>0 & `mul_series'!=. {
			sum priority if `dup'>0 & `dup'!=.
			local check=r(max)+`mul_series'
			local i=r(min)
	
			while `i'<=`check' {
				bys adm0_id fao_fct_name: egen cheap=min(mean) if priority==`i' & duplicates>0
				replace priority=`i'+1 if mean!=cheap & priority==`i' & duplicates>0
				drop cheap
				local i=`i'+1
			}		 
		}
		drop duplicates
	}
	drop missing
	
// apply third criteria for the series not satisfy first or second criteria but belong to the same group of other series satisfing the first criteria
	egen missing=rowmiss(priority)
	sum missing
	local p=r(max)
	if `p'==1 {
		replace pick=1 if check_sum!=0 & priority==. & (month_cover>=60 & series_m==12)
		replace criteria=1 if check_sum!=0 & priority==. & (month_cover>=60 & series_m==12)
		tempvar max_p
		bys adm0_id fao_fct_name: egen `max_p'=max(priority)
		bys adm0_id fao_fct_name: replace priority=`max_p'+1 if priority==. & check_sum!=0 & pick==1
	
		tempvar dup  // when third criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
		duplicates tag adm0_id fao_fct_name priority if pick==1 & flag==1, gen(`dup')
		bys adm0_id fao_fct_name: egen duplicates=mean(`dup') if criteria==2  & `dup'!=0
		sum `dup' 
		local mul_series=r(max)
		if `mul_series'>0 & `mul_series'!=. {
			sum priority if `dup'>0 & `dup'!=.
			local check=r(max)+`mul_series'
			local i=r(min)
	
			while `i'<=`check' {
				bys adm0_id fao_fct_name: egen cheap=min(mean) if priority==`i' & duplicates>0
				replace priority=`i'+1 if mean!=cheap & priority==`i' & duplicates>0
				drop cheap
				local i=`i'+1
			}			 
		}		
		drop duplicates
	}
	drop missing
	
** CRITERIA 2: longest series	
	egen missing=rowmiss(priority) if exception==1
	sum missing
	local p=r(max)
	if `p'==1 {
		replace pick=1 if check_sum==0 & (month_cover==longer & month_cover>=60 & series_m==12)
		replace criteria=2 if check_sum==0 & (month_cover==longer & month_cover>=60 & series_m==12)
		drop chec* equal_p
		bys adm0_id fao_fct_name: egen check=total(pick) if flag 
		bys adm0_id fao_fct_name: egen check_sum=total(pick)
		replace priority=1 if pick==1 & priority==.

		sum check if criteria==2 // when second criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
		local mul_series=r(max)
		if `mul_series'>1 & `mul_series'!=. {
			bys adm0_id fao_fct_name: egen equal_p=mean(check) if criteria==2
			sum equal_p
			local check=r(max)
			local i=2
	
			while `i'<=`check' {
				bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i'
				replace priority=`i' if mean!=. & expensive!=. & mean==expensive & equal_p==`i'
		
				local g=`i'
				while `g'>2 {
					drop expensive
					bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i'
					replace priority=`g'-1 if mean==expensive & equal_p==`i'
					local g=`g'-1
				}
				drop expensive	
				local i=`i'+1
			}
		}
	}
	drop missing
	
// apply third criteria for the series not satisfing second criteria but belong to the same group of other series satisfing the second criteria
	egen missing=rowmiss(priority) if exception==1
	sum missing
	local p=r(max)
	if `p'==1 {
		replace pick=1 if check_sum!=0 & priority==. & (month_cover>=60 & series_m==12)
		replace criteria=2 if check_sum!=0 & priority==. & (month_cover>=60 & series_m==12)
		tempvar max_p
		bys adm0_id fao_fct_name: egen `max_p'=max(priority) if criteria==2
		bys adm0_id fao_fct_name: replace priority=`max_p'+1 if priority==. & check_sum!=0 & pick==1 & criteria==2
	
		tempvar dup  // when third criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
		duplicates tag adm0_id fao_fct_name priority if pick==1 & flag==1 & criteria==2, gen(`dup')
		bys adm0_id fao_fct_name: egen duplicates=mean(`dup') if criteria==2  & `dup'!=0
		sum `dup' 
		local mul_series=r(max)
		if `mul_series'>0 & `mul_series'!=. {
			sum priority if `dup'>0 & `dup'!=.
			local check=r(max)+`mul_series'
			local i=r(min)
	
			while `i'<=`check' {
				bys adm0_id fao_fct_name: egen cheap=min(mean) if priority==`i' & duplicates>0 
				replace priority=`i'+1 if mean!=cheap & priority==`i' & duplicates>0 
				drop cheap
				local i=`i'+1
			}		 
		}		
		drop duplicates
	}
	drop missing
	
** CRITERIA 3: meet the minimum data requiremts		
	egen missing=rowmiss(priority) if exception==1
	sum missing
	local p=r(max)
	if `p'==1 {
		replace pick=1 if check_sum==0 & (month_cover>=60 & series_m==12)
		replace criteria=3 if check_sum==0 & (month_cover>=60 & series_m==12)
		drop chec* equal_p
		bys adm0_id fao_fct_name: egen check=total(pick) if flag 
		replace priority=1 if pick==1 & priority==. 
				
		sum check if criteria==3 // when third criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
		local mul_series=r(max)
		if `mul_series'>1 & `mul_series'!=. {
			bys adm0_id fao_fct_name: egen equal_p=mean(check) if criteria==3
			sum equal_p
			local check=r(max)
			local i=2
	
			while `i'<=`check' {
				bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i'
				replace priority=`i' if mean!=. & expensive!=. & mean==expensive & equal_p==`i'
		
				local g=`i'
				while `g'>2 {
					drop expensive
					bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i'
					replace priority=`g'-1 if mean==expensive & equal_p==`i'
					local g=`g'-1
				}
				drop expensive	
				local i=`i'+1
			}
		}
	}
	drop missing

	assert check!=0 | exception==1
	drop series_m1-series_m12 d1-d12 data_count criteria pick flag mean check  	

*********************************************************	
*	adjust priority for price series within the same	*
*	fao_fct_name for the countries whose price series 	*
*	are shorther than 5 year but at least 3 year long	* 
*********************************************************	
	sort series time
	
** CRITERIA 1: the longest and more complete series	
	gen criteria=. 
	gen pick=(month_cover==longer & month_cover>=36 & gap==complete & series_m==12 & exception==1)	
	replace criteria=1 if pick==1
	egen flag=tag(adm0_id cm_id pt) if exception==1
	bys adm0_id fao_fct_name: egen check=total(pick) if flag & exception==1
	bys adm0_id fao_fct_name: egen check_sum=total(pick) if exception==1
	replace priority=1 if pick==1 // highest priority is for the longest and more complete series
	
	sum check  // when first criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
	local mul_series=r(max)
	if `mul_series'>1 & `mul_series'!=.{
		tempvar mean   
		bys series: egen `mean'=mean(price) if t>date_end-36 & exception==1
		bys series: egen mean=mean(`mean') if exception==1
		bys adm0_id fao_fct_name: egen equal_p=mean(check) if exception==1 
		sum equal_p if exception==1
		local check=r(max)
		local i=2
	
		while `i'<=`check' {
			bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i' & exception==1
			replace priority=`i' if mean!=. & expensive!=. & mean==expensive & equal_p==`i' & exception==1
		
			local g=`i'
			while `g'>2 {
				drop expensive
				bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i' & exception==1
				replace priority=`g'-1 if mean==expensive & equal_p==`i' & exception==1
				local g=`g'-1
			}
			drop expensive	
			local i=`i'+1
		}
	}
	
	 // apply second criteria for the series not satisfy first criteria but belong to the same group of other series satisfing the first criteria
	egen missing=rowmiss(priority) if exception==1
	sum missing
	local p=r(max)
	if `p'==1 {
		replace pick=1 if check_sum!=0 & priority==. & (month_cover==longer & month_cover>=36 & series_m==12) & exception==1
		replace criteria=1 if check_sum!=0 & priority==. & (month_cover==longer & month_cover>=36 & series_m==12) & exception==1
		tempvar max_p
		bys adm0_id fao_fct_name: egen `max_p'=max(priority) if exception==1
		bys adm0_id fao_fct_name: replace priority=`max_p'+1 if priority==. & check_sum!=0 & pick==1 & exception==1
	
		tempvar dup  // when second criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
		duplicates tag adm0_id fao_fct_name priority if pick==1 & flag==1 & exception==1, gen(`dup')
		bys adm0_id fao_fct_name: egen duplicates=mean(`dup') if criteria==2  & `dup'!=0 & exception==1
		sum `dup' if exception==1
		local mul_series=r(max)
		if `mul_series'>0 {
			sum priority if `dup'>0 & `dup'!=. & exception==1
			local check=r(max)+`mul_series'
			local i=r(min)
	
			while `i'<=`check' {
				bys adm0_id fao_fct_name: egen cheap=min(mean) if priority==`i' & duplicates>0 & exception==1
				replace priority=`i'+1 if mean!=cheap & priority==`i' & duplicates>0 & exception==1
				drop cheap
				local i=`i'+1
			}			 
		}
		drop duplicates
	}
	drop missing
	
	 // apply third criteria for the series not satisfy first or second criteria but belong to the same group of other series satisfing the first criteria
	egen missing=rowmiss(priority) if exception==1
	sum missing
	local p=r(max)
	if `p'==1 {
		replace pick=1 if check_sum!=0 & priority==. & (month_cover>=36 & series_m==12) & exception==1
		replace criteria=1 if check_sum!=0 & priority==. & (month_cover>=36 & series_m==12) & exception==1
		tempvar max_p
		bys adm0_id fao_fct_name: egen `max_p'=max(priority) if exception==1
		bys adm0_id fao_fct_name: replace priority=`max_p'+1 if priority==. & check_sum!=0 & pick==1 & exception==1
	
		tempvar dup  // when third criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
		duplicates tag adm0_id fao_fct_name priority if pick==1 & flag==1 & exception==1, gen(`dup')
		bys adm0_id fao_fct_name: egen duplicates=mean(`dup') if criteria==2  & `dup'!=0 & exception==1
		sum `dup' if exception==1
		local mul_series=r(max)
		if `mul_series'>0 {
			sum priority if `dup'>0 & `dup'!=. & exception==1
			local check=r(max)+`mul_series'
			local i=r(min)
	
			while `i'<=`check' {
				bys adm0_id fao_fct_name: egen cheap=min(mean) if priority==`i' & duplicates>0 & exception==1
				replace priority=`i'+1 if mean!=cheap & priority==`i' & duplicates>0 & exception==1
				drop cheap
				local i=`i'+1
			}
		}		
		drop duplicates
	}
	drop missing
	
** CRITERIA 2: longest series	
	egen missing=rowmiss(priority) if exception==1
	sum missing
	local p=r(max)
	if `p'==1 {
		replace pick=1 if check_sum==0 & (month_cover==longer & month_cover>=36 & series_m==12) & exception==1
		replace criteria=2 if check_sum==0 & (month_cover==longer & month_cover>=36 & series_m==12) & exception==1
		drop chec* equal_p
		bys adm0_id fao_fct_name: egen check=total(pick) if flag & exception==1
		bys adm0_id fao_fct_name: egen check_sum=total(pick) if exception==1
		replace priority=1 if pick==1 & priority==. & exception==1

		sum check if criteria==2 & exception==1 // when second criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
		local mul_series=r(max)
		if `mul_series'>1 & `mul_series'!=. {
			bys adm0_id fao_fct_name: egen equal_p=mean(check) if criteria==2 & exception==1
			sum equal_p if exception==1
			local check=r(max)
			local i=2
	
			while `i'<=`check' {
				bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i' & exception==1
				replace priority=`i' if mean!=. & expensive!=. & mean==expensive & equal_p==`i' & exception==1
		
				local g=`i'
				while `g'>2 {
					drop expensive
					bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i' & exception==1
					replace priority=`g'-1 if mean==expensive & equal_p==`i' & exception==1
					local g=`g'-1
				}
				drop expensive	
				local i=`i'+1
			}
		}
	}
	drop missing
	
	 // apply third criteria for the series not satisfing second criteria but belong to the same group of other series satisfing the second criteria
	egen missing=rowmiss(priority) if exception==1
	sum missing
	local p=r(max)
	if `p'==1 {
		replace pick=1 if check_sum!=0 & priority==. & (month_cover>=36 & series_m==12) & exception==1
		replace criteria=2 if check_sum!=0 & priority==. & (month_cover>=36 & series_m==12) & exception==1
		tempvar max_p
		bys adm0_id fao_fct_name: egen `max_p'=max(priority) if criteria==2 & exception==1
		bys adm0_id fao_fct_name: replace priority=`max_p'+1 if priority==. & check_sum!=0 & pick==1 & criteria==2 & exception==1
	
		tempvar dup  // when third criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
		duplicates tag adm0_id fao_fct_name priority if pick==1 & flag==1 & criteria==2 & exception==1, gen(`dup')
		bys adm0_id fao_fct_name: egen duplicates=mean(`dup') if criteria==2  & `dup'!=0 & exception==1
		sum `dup' if exception==1
		local mul_series=r(max)
		if `mul_series'>0 & `mul_series'!=.{
			sum priority if `dup'>0 & `dup'!=.
			local check=r(max)+`mul_series'
			local i=r(min)
	
			while `i'<=`check' {
				bys adm0_id fao_fct_name: egen cheap=min(mean) if priority==`i' & duplicates>0 
				replace priority=`i'+1 if mean!=cheap & priority==`i' & duplicates>0 
				drop cheap
				local i=`i'+1
			}		 
		}		
		drop duplicates
	}
	drop missing	
	
** CRITERIA 3: meet the minimum data requiremts		
	egen missing=rowmiss(priority) if exception==1
	sum missing
	local p=r(max)
	if `p'==1 {
		replace pick=1 if check_sum==0 & (month_cover>=36 & series_m==12) & exception==1
		replace criteria=3 if check_sum==0 & (month_cover>=36 & series_m==12) & exception==1
		drop chec* equal_p
		bys adm0_id fao_fct_name: egen check=total(pick) if flag & exception==1
		replace priority=1 if pick==1 & priority==. & exception==1
	
		sum check if criteria==3 & exception==1 // when third criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
		local mul_series=r(max)
		if `mul_series'>1 & `mul_series'!=. {
			bys adm0_id fao_fct_name: egen equal_p=mean(check) if criteria==3 & exception==1
			sum equal_p if exception==1
			local check=r(max)
			local i=2
	
			while `i'<=`check' {
				bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i' & exception==1
				replace priority=`i' if mean!=. & expensive!=. & mean==expensive & equal_p==`i' & exception==1
		
				local g=`i'
				while `g'>2 {
					drop expensive
					bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i' & exception==1
					replace priority=`g'-1 if mean==expensive & equal_p==`i' & exception==1
					local g=`g'-1
				}
				drop expensive	
				local i=`i'+1
			}
		}
	}
	drop missing
	

	assert check!=0 

*** Give priority to series with more recent data
	gen change=.
	local change=1
	while `change'==1 {
		tempvar high_priority
		bys adm0_id fao_fct_name: egen `high_priority'=min(priority)
		tempvar max_end
		bys adm0_id fao_fct_name: egen `max_end'=max(date_end)	
		replace change=1 if priority==`high_priority' & date_end<`max_end'
		drop if change==1
		
		tempvar high_priority
		bys adm0_id fao_fct_name: egen `high_priority'=min(priority)
		tempvar max_end
		bys adm0_id fao_fct_name: egen `max_end'=max(date_end)	
		replace change=1 if priority==`high_priority' & date_end<`max_end'		
		sum change
		local change=r(max)
	}

