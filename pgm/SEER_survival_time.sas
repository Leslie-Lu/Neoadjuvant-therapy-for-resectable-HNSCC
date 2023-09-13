
/* Version 2.10 CalculateSurvivalTimeInMonths.sas                                  */
/* This SAS program is provided to calculate 8 fields which are described at       */
/*  http://seer.cancer.gov/survivaltime/                                           */
/*  In addition to descriptions of the fields, you can find other documentation    */
/*  and contact information on the web page.                                       */

/* The following Notes section is only applicable for SEER*Prep versions prior to  */
/*   2.5.3 and dd files with date prior to 2/2/2016.  For newer versions, please   */
/*   see Version 2.4 updates.                                                      */
/* Notes for anyone using the output file of this program in SEER*Prep             */
/*   When you create a database with SEER*Prep, the default is to NOT include the  */
/*   database in the survival session.  To enable survival, prior to creating the  */
/*   database, use the Database Options dialog (File menu) and select Survival.    */
/*   Hand-edits will also be required to either the dd file prior to creating the  */
/*   database, or to the database.ini file after creating the database.  This is   */
/*   required to enable SEER*Stat to use the pre-calculated survival time fields   */
/*   for the survival calculations.  It's not enabled by default to avoid it being */
/*   used in databases that did not include these fields. To make the change, open */
/*   the database.ini file or dd file with a text editor and search for            */
/*   "XXXSurvivalTimeMonths1" and "XXXSurvivalTimeMonths2".  Removing "XXX" from   */
/*   both of these will enable both presumed alive and non-presumed alive survival */
/*   in the database.  If you only want the non-presumed alive, just remove the    */
/*   "XXX" from "XXXSurvivalTimeMonths1".  If only presumed alive is desired, more */
/*   changes are needed.  Remove all of the SurvivalTimexxxxx1 fields and change   */
/*   the 2 to 1 in the SurvivalTimexxxxx2 fields.  Please don't hesitate to        */
/*   contact SEER*Stat technical support (seerstat@imsweb.com) with questions.     */

/* Version 2.1 (9/24/13) fixed the start day in the situation where a patient had: */
/*    - 2 or more tumor records                                                    */
/*    - the first record was the same month and year as they were born             */
/*    - birth day was known                                                        */
/*    - dx day was not known                                                       */
/* Update 8/27/14: Added a check for date of last contact past today's date.			 */
/* Update 9/26/14: Added a check to see if there are inter-record conflicts on     */
/*      date of last contact and vital status - must be same on all records        */

/* Version 2.3 (10/1/2015)                                                         */
/* Changed the default for the study cut-off to 12/31/2013                         */
/* If diagnosis date is after study cut-off survival time fields are 9-filled      */

/* Version 2.4 (2/2/2016)                                                          */
/*   - updated column locations for survival time fields to NAACCR defined columns */
/*   - changed sort order of output txd file to be state dx, patient id, and       */
/*     record order (Record number recode in SEER*Prep).                           */
/*     It had been state dx, patient id, and sequence number central.  The problem */
/*     with this is that SEER*Prep and SEER*Stat expect the tumors for a patient   */
/*     to be sorted chronologically, and sequence number central is not            */
/*     chronological if non-federally reportable tumors are included               */
/*     i.e. sequence numbers 60-89.                                                */
/*   - SEER*Prep version 2.5.3 (or later) allows you to pick which field you used  */
/*     for sorting the tumors for each patient, but you should use record number   */
/*     recode if including the non-federally reportable tumors.  This field is     */
/*     created by this program and output in columns 2510-2511 and new dd files    */
/*     have this field defined and allow for it to be the tumor sort field.        */
/*   - Additional note for those using the resultant data file for SEER*Prep:      */
/*     In dd files dated 2/2/2016 or later, databases will be available by default */
/*     in SEER*Stat's survival session.  There is also a new option if using the   */
/*     new dd file and SEER*Prep Version 2.5.3 or later.  The option will allow    */
/*     you to specify whether survival calculations can be performed in SEER*Stat  */
/*     using presumed alive survival, reported alive survival, or both.  It will   */
/*     also allow you to pick the default.  The one used as the default would be   */
/*     the version used for all prevalence calculations.                           */

/* Version 2.5 (11/3/2016)                                                         */
/* Changed the default for the study cut-off to 12/31/2014                         */

/* Version 2.6 (10/5/2017)                                                         */
/* Changed the default for the study cut-off to 12/31/2015                         */

/* Version 2.7 (5/30/2018)                                                         */
/* Added Vital Status Recode - logic for recode:                                   */
/*   - Vital Status Recode = vit_stat                                              */
/*   - if Year of lc > study cut-off year then Vital Status recode = 1 (alive)     */

/* Version 2.8 (9/10/2018)                                                         */
/*   - Changed the default for the study cut-off to 12/31/2016                     */
/*   - Changed "Includedays" to "Excludedays" and made the logic more logical      */
/*        1 (true) means exclude and 0 (false) means don't exclude                 */

/* Version 2.9 (11/15/2018)                                                        */
/*   - Fixed a bug for cases diagnosed after study-cut-off date                    */
/*   - had been putting these cases first in record number recode and was          */
/*        changing date of diagnosis.  Now they are in correct order               */
/*        and date of diagnosis recode is fixed - original date or fixed within    */
/*        year if there were missing month/day                                     */
/*   - calculations of flags will not be changed in this version and there is code */
/*        below that ensures this.  In the future, we might change flag            */
/*        calculation to use the original date of last contact, rather than the    */
/*        study cut-off version.  This would only impact cases diagnosed in the    */
/*        study cut-off month.                                                     */             

/* Version 2.10 (9/16/2019)                                                        */
/*   - changed year_dx to years(1) to fix problem with unknown DX month in birth   */
/*     or year when person has multiple records - and not all are in year of birth.*/
/*     It was not using month of birth as constraint.                              */
/*   - Changed the default for the study cut-off to 12/31/2017                     */
/*   - Changed input and output columns to NAACCR record layout version 18         */
  
options missing=' ';

filename in  "input.txt";
filename out "myoutputfile.txt";    /* if using in SEER*Prep, change extension to .txd  */

/* Assumptions:                                                               */
/*   study cutoff will be 12/31/xxxx                                          */
/*   no unknown years for dx or last contact                                  */
/*   setup to handle max of 49 tumors                                         */
/*   date of last contact is the same for all records for a patient           */
/*   calculates fields for cases with dx thru study cutoff date, not beyond   */

%LET STUDYCUTOFFYEAR = 2017;
%LET STUDYCUTOFFMONTH = 12;
%LET STUDYCUTOFFDAY = 31;
%LET DAYS_IN_MONTH = (365.24/12);
%LET Excludedays = 0; /* setting Excludedays to 1 will remove days from the output */

/* First read in the data and sort it such that the records are in order of diagnosis.       */
/* Can't just use sequence number, because sequence numbers 60+ are non-federally reportable */
/* and would all come after the federally reportable tumors regardless of date of dx.        */
/* The sort we want is by date dx and then sequence number, so that if multiple tumors have  */
/* the same date of diagnosis, we will use sequence number as the tie-breaker for the sort.  */
/* In the event of ties, a federally reportable tumor will occur before the non-federally    */
/* reportable tumor.                                                                         */

data fullrec (keep = record order)  fed (drop = record) nonfed (drop = record);
  infile in lrecl=4048;
  input @   1 record      $char4048. /* buffer to read full "incidence" file record - NAACCR type "I" */
        @  42 pat_id      8.         /* NAACCRItemNumber 20   */
        @ 124 state       $char2.    /* NAACCRItemNumber 80   */
        @ 542 seq_num     2.         /* NAACCRItemNumber 380  */
        @ 544 year_dx     4.         /* NAACCRItemNumber 390  */
        @ 548 month_dx    2.         /* NAACCRItemNumber 390  */
        @ 550 day_dx      2.         /* NAACCRItemNumber 390  */
        @ 577 rept_src    1.         /* NAACCRItemNumber 500  */
        @2775 year_lc     4.         /* NAACCRItemNumber 1750 */
        @2779 month_lc    2.         /* NAACCRItemNumber 1750 */
        @2781 day_lc      2.         /* NAACCRItemNumber 1750 */
        @2785 vit_stat    1.         /* NAACCRItemNumber 1760 */
        @ 226 month_bt    2.
        @ 230 year_bt     4.
        @ 232 day_bt      2.
        ;
  order = _n_;

  /* Verison 2.0 change - need original values - not adjusted for study cut-off date */
  orig_month_lc = month_lc;
  orig_day_lc = day_lc;
  orig_year_lc = year_lc;
  orig_year_dx = year_dx;
  orig_month_dx=month_dx;
  orig_day_dx=day_dx;
  vit_stat_rec = vit_stat;
  /* if date of last contact is beyond study cut-off, set to study cut-off */
  if year_lc > &STUDYCUTOFFYEAR then do;
    year_lc = &STUDYCUTOFFYEAR;
    month_lc = &STUDYCUTOFFMONTH;
    day_lc = &STUDYCUTOFFDAY;
    vit_stat_rec = 1; /* alive */
    end;
    	  
    /* 11/15/18 - version 2.9 - no longer setting date dx to missing if beyond study cutoff */
    if (1900>year_dx or year_dx=.) then do;    	
    	year_dx= .;
    	month_dx= .;
    	day_dx= .;
    	surv_flag= 9;
    	pa_surv_flag= 9;
    end;
     
    /* 11/15/18 - version 2.9 - if year_dx after study cut-off then don't set date lc to missing */
    if (1900>year_lc or year_lc=. or (year_lc<year_dx and year_dx <= &STUDYCUTOFFYEAR)) then do;
    	year_lc= .;
    	month_lc= .;
    	day_lc= .;
    	surv_flag= 9;
    	pa_surv_flag= 9;
    end;

    /*define today's date using sas date functions*/
    date_today=today();
    day_today=day(date_today);
    month_today=month(date_today);
    year_today=year(date_today);

		if (year_lc>year_today or (year_lc=year_today and month_lc>month_today) or (year_lc=year_today and month_lc=month_today and day_lc>day_today)) then do;
    	year_lc= .;
    	month_lc= .;
    	day_lc= .;
    	surv_flag= 9;
    	pa_surv_flag= 9;
    end;

  if (month_dx<1 or month_dx>12) then month_dx= .;
  if month_dx = . then day_dx = .;  /* if month is missing, then treat day as missing even if it was not */
  if (month_lc<1 or month_lc>12) then month_lc= .;
  if month_lc = . then day_lc = .;
  if (month_bt<1 or month_bt>12) then month_bt= .;
  if month_bt = . then day_bt = .;
  /*set invalid dates to missing*/
  if (month_dx in (1,3,5,7,8,10,12) and (day_dx<1 or day_dx>31)) then day_dx= .;
  if (month_dx in (4,6,9,11) and (day_dx<1 or day_dx>30)) then day_dx= .;
  if (month_dx = 2 and (day_dx<1 or (day_dx> day(mdy(3,1,year_dx) - 1)))) then day_dx= .;
  if (month_lc in (1,3,5,7,8,10,12) and (day_lc<1 or day_lc>31)) then day_lc= .;
  if (month_lc in (4,6,9,11) and (day_lc<1 or day_lc>30)) then day_lc= .;
  if (month_lc = 2 and (day_lc<1 or (day_lc> day(mdy(3,1,year_lc) - 1)))) then day_lc= .;
  if (month_bt in (1,3,5,7,8,10,12) and (day_bt<1 or day_bt>31)) then day_bt= .;
  if (month_bt in (4,6,9,11) and (day_bt<1 or day_bt>30)) then day_bt= .;
  if (month_bt = 2 and (day_bt<1 or (day_bt> day(mdy(3,1,year_bt) - 1)))) then day_bt= .;
  /* retain original values, needed for 2nd set of variables (presumed alive version) and useful for inspecting changes */
  o_month_dx = month_dx;
  o_month_lc = month_lc;
  o_day_dx = day_dx;
  o_day_lc = day_lc;
  o_year_dx = year_dx;
  o_year_lc = year_lc;
  if seq_num < 60 or seq_num >= 98 then output fed;
  else output nonfed;
  output fullrec;
run;

/* To insert the sequence # 60+ tumors in with the sequence # < 60 tumors, need a temporary  */
/* date variable to sort by that will have no unknown values.  The assigned value will just  */
/* need to preserve the order and make the < 60s come before 60+ when tied or unknown order. */
/* To accomplish this, when there is unknown month or day for a tumor, we will assign the    */
/* earliest possible date to keep the sequence # order for < 60, and the latest date for 60+ */
/* The earliest and latest are based on other tumors of that type for the patient.           */
/* E.g. sequence # 1 - dx 99/99/2000 - using 99 in example, but would really be blank        */
/*      sequence # 2 - dx 4/1/2000,                                                          */
/*      sequence # 60 - dx 99/99/2000                                                        */
/*      temp date for sequence # 1 = 1/1/2000 - need it to come before sequence # 2          */
/*      temp date for sequence # 3 = 12/31/2000 - no other 60+ tumors in 2000, so use 12/31  */

/* sort fed so we can assign min possible date based on prior tumor */
proc sort data = fed;
  by state pat_id seq_num;
run;

/* sort nonfed with descending seq_num so we can assign max possible date based on later tumor */
proc sort data = nonfed;
  by state pat_id DESCENDING seq_num;
run;

/* This data set is assigning temporary dates to any missing dates such that sorting by date */
/* would preserve sequence number sort.  This is working with federally reportable tumors.   */
data fed;
  set fed;
  by state pat_id;
  retain tmp_year tmp_month tmp_day;
  if first.pat_id then do;
    tmp_year = year_dx;
    tmp_month = month_dx;
    tmp_day = day_dx;
    if tmp_month = . then tmp_month = 1;
    if tmp_day = . then tmp_day = 1;
    end;
  else do; /* not the first tumor for the person */
    if month_dx = . then do;
      if year_dx ^= tmp_year then do; /* this tumor has dx year different than prior tumor */
        tmp_month = 1;
        tmp_day = 1;
        end;
      /* if year_dx = tmp_year - then it is the same as prior record, so keep tmp_month and */
      /* tmp_day from prior tumor                                                           */
      end;
    else if day_dx = . then do;
      if year_dx ^= tmp_year or month_dx ^= tmp_month then do;
        tmp_month = month_dx;
        tmp_day = 1;
        end;
      /* if year_dx = tmp_year and month_dx = tmp_month - then it is the same as prior record */
      /* so keep tmp_month and day from prior                                                 */
      end;
    else do; /* no missing components */
      tmp_month = month_dx;
      tmp_day = day_dx;
      end;
    tmp_year = year_dx;  /* this will be used for next record for patient */
    end;
run;

/* This data set is assigning temporary dates to any missing dates such that sorting by date   */
/* would preserve sequence number sort.  This is working with NON-federally reportable tumors. */
data nonfed;
  set nonfed;
  by state pat_id;
  retain tmp_year tmp_month tmp_day;
  if first.pat_id then do;
    tmp_year = year_dx;
    tmp_month = month_dx;
    tmp_day = day_dx;
    if tmp_month = . then tmp_month = 12;
    if tmp_day = . then tmp_day = 31;
    end;
  else do; /* not the first tumor for the person */
    if month_dx = . then do;
      if year_dx ^= tmp_year then do; /* this tumor has dx year different than prior tumor */
        tmp_month = 12;
        tmp_day = 31;
        end;
      /* if year_dx = tmp_year - then it is the same as prior record, so keep tmp_month and */
      /* tmp_day from prior tumor                                                           */
      end;
    else if day_dx = . then do;
      if year_dx ^= tmp_year or month_dx ^= tmp_month then do;
        tmp_month = month_dx;
        tmp_day = 31;         /* could be 2/31, but only used for sort so it won't be a problem */
        end;
      /* if year_dx = tmp_year and month_dx = tmp_month - then it is the same as prior record */
      /* so keep tmp_month and day from prior                                                 */
      end;
    else do; /* no missing components */
      tmp_month = month_dx;
      tmp_day = day_dx;
      end;
    tmp_year = year_dx;  /* this will be used for next record for patient */
    end;
run;

data all;
  set fed nonfed;
run;

/*
proc freq data = all;
  tables month_dx day_dx month_lc day_lc;
  title "All records pre-fix";
run;
*/

proc sort data = all;
  by state pat_id tmp_year tmp_month tmp_day seq_num;
run;

/* Calc fields without using presumed alive.                                            */
/* Prior to calculating survival time, we need to assign non-missing values to          */
/* all date components that are missing (month or day of diagnosis or last contact).    */
/* Code written to handle up to 50 dates (49 diagnoses and date of last contact).       */
/* This data step sets up arrays of years, months, days, and missing value flags.       */
/* At the end of the data step, the last record for a patient will have dates           */
/* from all diagnoses and the date of last contact filled into the arrays and           */
/* all missing components will be assigned non-missing values based on the              */
/* following algorithm.  If any dates have missing day, but known month, assign day.    */
/* Day is assigned to middle of "possible" time window.  If no other dates are in       */
/* same month, then the middle of the month is selected, if other dates are in the      */
/* same month, day is placed in the middle of possible time period.  Middle is          */
/* calculated as floor((earliest possible day + latest possible day)/2)                 */
/* Then it makes a second pass, assigning value to month and day when month is missing. */
/* The same method of picking the middle of the time window is used.  If multiple days  */
/* are missing in the same month or months are missing in the same year, the earliest   */
/* missing value is resolved first.  E.g. dx = 12/99/2004, lc = 12/99/2004, assign      */
/* day dx = 16 (floor((1+31)/2)), then assign day lc = 23 (floor((16+31)/2)).           */
/* New 9/26/2014 - check to see if there are any inter-record errors on date of lc and  */
/* vital status.  If so, survival times will be 9 filled and imputed dates blanked out  */
data all;
  set all;
  by state pat_id;
  retain record_order missing1-missing50 year1-year50 month1-month50 day1-day50 f_year_bt f_month_bt f_day_bt tmp_year_lc tmp_month_lc tmp_day_lc tmp_vit_stat tmp_conflict_lc;
  array missings(50) missing1-missing50;
  array years(50) year1-year50;
  array months(50) month1-month50;
  array days(50) day1-day50;
  if first.pat_id then do;
    record_order = 0;
    f_year_bt = year_bt;
    f_month_bt = month_bt;
    f_day_bt = day_bt;
    tmp_conflict_lc = 0;
    tmp_year_lc = year_lc;
    tmp_month_lc = month_lc;
    tmp_day_lc = day_lc;
    tmp_vit_stat = vit_stat;
    do i = 1 to 50;
      missings(i) = .;
      years(i) = .;
      months(i) = .;
      days(i) = .;
      end;
    end;

  if tmp_year_lc ^= year_lc or tmp_month_lc ^= month_lc or tmp_day_lc ^= day_lc or tmp_vit_stat ^= vit_stat then tmp_conflict_lc = 1;
  record_order = record_order + 1; /* first record will be 1 */
  years(record_order) = year_dx;
  if year_dx = . then years(record_order) = 9999;  /* set to unrealistically high value, so we get  */
                                                   /* negative survival time - all will be 9 filled */
  months(record_order) = month_dx;
  days(record_order) = day_dx;
  if month_dx = . or day_dx = . then missing_dx = 1;
  else missing_dx = 0;
  missings(record_order) = missing_dx;
  if last.pat_id then do;
    numrecs = record_order;
    years(numrecs+1) = year_lc;
    if year_lc = . then years(numrecs+1) = 1900;  /* set to unrealistically low value, so we get   */
                                                  /* negative survival time - all will be 9 filled */
    months(numrecs+1) = month_lc;
    days(numrecs+1) = day_lc;
    if month_lc = . or day_lc = . then missing_lc = 1;
    else missing_lc = 0;
    missings(numrecs+1) = missing_lc;
    /* pass 1, fix any missing days when month is known */
    do i = 1 to numrecs+1;
      if (i = 1) then do;
        if (years(i)=f_year_bt and months(i)=f_month_bt and f_day_bt^=.) then day_start_constraint=f_day_bt;
        else day_start_constraint = 1;
      end;
      if months(i) ^= . then do;
        if months(i) in (1,3,5,7,8,10,12) then number_days_in_month = 31;
        else if months(i) in (4,6,9,11) then number_days_in_month = 30;
        else do;  /* Feb - get last day of Feb in current year by looking at day before March 1 */
          number_days_in_month = day(mdy(3,1,years(i)) - 1);
          end;
        end;
      day_end_constraint = number_days_in_month;
      bdone = 0;
      j = i+1;
      if i > 1 then do;
        if years(i) = years(i-1) and months(i) = months(i-1) then day_start_constraint = days(i-1);
        else day_start_constraint = 1;
        end;
      if months(i) ^= . and days(i) = . then do; /* missing day but not month */
        do until (bdone = 1);
          if years(i) ^= years(j) or months(i) ^= months(j) then bdone = 1;
          else if days(j) ^= . then do;
            day_end_constraint = days(j);
            bdone = 1;
            end;
          if j = numrecs + 1 then bdone = 1;
          j = j+1;
          end; /* end do until */
        days(i) = floor((day_start_constraint + day_end_constraint)/2);
        end;
      end;
    /* pass 2, fix any missing months (and days) - all dates with known month will now have complete date */
    day_start_constraint = 1;
    /* SMS - 9/16/2019 - changed year_dx to years(1) to fix problem with unknown DX month in birth or year when */
    /* person has multiple records - and not all are in year of birth.  Was not using month of birth as constraint */
    if (years(1)=year_bt and month_bt ^=.) then do;  
    	month_start_constraint=month_bt;
    	if day_bt^=. then day_start_constraint=day_bt;
  	end;
    else month_start_constraint = 1;
    do i = 1 to numrecs+1;
      day_end_constraint = 31;
      month_end_constraint = 12;
      bdone = 0;
      j = i+1;
      if i > 1 then do;
        if years(i) = years(i-1) then do;
          day_start_constraint = days(i-1);
          month_start_constraint = months(i-1);
          end;
        else if years(i) ^= f_year_bt then do; /* fix case with date of dx imputed within year of birth for people with multiple primaries 7/18/2019 */
          day_start_constraint = 1;
    			month_start_constraint = 1;
          end;
        end;
      if months(i) = . then do;
        do until (bdone = 1);
          if years(i) ^= years(j) then bdone = 1;
          else if months(j) ^= . then do;
            day_end_constraint = days(j);
            month_end_constraint = months(j);
            bdone = 1;
            end;
          if j = numrecs + 1 then bdone = 1;
          j = j+1;
          end; /* end do until */
        tempstart = mdy(month_start_constraint, day_start_constraint, years(i));
        tempend = mdy(month_end_constraint, day_end_constraint, years(i));
        newdate = floor((tempstart+tempend)/2);
        months(i) = month(newdate);
        days(i) = day(newdate);
        end;
      end;
    end;
run;

/* Sort such that patients records are reversed.  This is because the last record for the */
/* patient has all of the corrected information.                                          */
proc sort data = all;
  by state pat_id DESCENDING record_order;
run;

/* This data set retains information from last record for patient (with all fixed dates)      */
/* and assigns the fixed dates to the appropriate tumor record.  Then calculates the survival */
/* months and flag for the NON presumed alive version of the fields.  Survival months is      */
/* calculated as (date of last contact-date of dx)/DaysInAMonth.  DaysInAMonth = 365.24/12.   */
data all;
  set all;
  by state pat_id;
  retain index_lc missing1-missing50 year1-year50 month1-month50 day1-day50 n_missing1-n_missing50
         n_year1-n_year50 n_month1-n_month50 n_day1-n_day50 year_lc month_lc day_lc conflict_lc;
  drop missing1-missing50 year1-year50 month1-month50 day1-day50 n_missing1-n_missing50
       n_year1-n_year50 n_month1-n_month50 n_day1-n_day50;
  array missings(50) missing1-missing50;
  array years(50) year1-year50;
  array months(50) month1-month50;
  array days(50) day1-day50;
  array n_missings(50) n_missing1-n_missing50;
  array n_years(50) n_year1-n_year50;
  array n_months(50) n_month1-n_month50;
  array n_days(50) n_day1-n_day50;
  if first.pat_id then do;
    index_lc = numrecs + 1;
    conflict_lc = tmp_conflict_lc;
    do i = 1 to numrecs+1;
      n_missings(i) = missings(i);
      n_years(i) = years(i);
      n_months(i) = months(i);
      n_days(i) = days(i);
      end;
    end;
  missing_dx = n_missings(record_order);
  year_dx = n_years(record_order);
  month_dx = n_months(record_order);
  day_dx = n_days(record_order);
  missing_lc = n_missings(index_lc);
  year_lc = n_years(index_lc);
  month_lc = n_months(index_lc);
  day_lc = n_days(index_lc);
  surv_days = mdy(month_lc, day_lc, year_lc) - mdy(month_dx, day_dx, year_dx);
  surv_mon = floor(surv_days/&DAYS_IN_MONTH);
 if surv_flag=. then do;
  if missing_dx = 1 or missing_lc = 1 then do;
    if year_dx = year_lc and (o_month_dx = o_month_lc or o_month_dx = . or o_month_lc = .) then do;
      surv_flag = 2; /* some unknown - could be 0 days */
      end;
    else surv_flag = 3; /* some unknown - can't be 0 days */
    end;
  else do; /* no missing values */
    if surv_days = 0 then surv_flag = 0; /* complete dates, 0 days */
    else surv_flag = 1; /* complete dates, not 0 days */
    end;
  end;
run;

/* recalc fields using presumed alive */
proc sort data = all;
  by state pat_id record_order;
run;

/* Next block of code is identical to prior, except all alive patients have date of last contact  */
/* set to study cut-off date.  First step is to assign the last contact for alive and then reset  */
/* reset all missing values to missing.  Then the logic is the same as above.                     */

/* Verison 2.0 change - This block is calculating dates for presumed alive.                       */
/*   Rather than starting over, keep assigned values for diagnosis from above block.  It was      */
/*   created using known information, so keeping it makes sense.                                  */
/*   E.g. Patient with dx and last contact in 2000, date of last contact is 2/8/2000 and patient  */
/*        is alive.  Date of dx has unknown month and day, but year is 2000.  Dx should be on or  */
/*        before 2/8/2000. Block above would have assigned the mid point of 1/1/2000 and 2/8/2000 */
/*        which is 1/20/2000.  With version 1, we would first assign date of last contact         */
/*        to 12/31/2011.  Then the date of dx would be the only date in 2000 and therefore be the */
/*        midpoint of 1/1/2000 and 12/31/2000 (7/2/2000).  With this version we will keep dx as   */
/*        1/20/2000 and presumed alive date of last contact will be 12/31/2011.  Using known      */
/*        information - it should be on or before the original known date of last contact.        */
/*   Also need to keep track of non-presumed alive date of last contact adjusted for study        */
/*   cut-off and with assigned values for missing components to write to output file.             */
data all;
  set all;
  by state pat_id;
  retain record_order missing1-missing50 year1-year50 month1-month50 day1-day50 f_year_bt f_month_bt f_day_bt;
  array missings(50) missing1-missing50;
  array years(50) year1-year50;
  array months(50) month1-month50;
  array days(50) day1-day50;
  if first.pat_id then do;
    f_year_bt = year_bt;
    f_month_bt = month_bt;
    f_day_bt = day_bt;
    do i = 1 to 50;
      missings(i) = .;
      years(i) = .;
      months(i) = .;
      days(i) = .;
      end;
    end;
  /* Verison 2.0 change - retain non-presumed alive date of last contact */
  fixed_year_lc = year_lc;
  fixed_month_lc = month_lc;
  fixed_day_lc = day_lc;
  if vit_stat = 1 then do;
    year_lc = &STUDYCUTOFFYEAR;
    month_lc = &STUDYCUTOFFMONTH;
    day_lc = &STUDYCUTOFFDAY;
    pa_surv_flag=.;
    end;
  else do;
    month_lc = o_month_lc;
    day_lc = o_day_lc;
    end;
  /* month_dx = o_month_dx; DON'T RESET DX SP_CHANGE */
  /* day_dx = o_day_dx; DON'T RESET DX SP_CHANGE */
  years(record_order) = year_dx;
  if year_dx = . then years(record_order) = 9999;  /* set to unrealistically high value, so we get  */
                                                   /* negative survival time - all will be 9 filled */
  months(record_order) = month_dx;
  days(record_order) = day_dx;
  if o_month_dx = . or o_day_dx = . then missing_dx = 1; /* Set missing based on original date SP_CHANGE */
  else missing_dx = 0;
  missings(record_order) = missing_dx;
  if last.pat_id then do;
    numrecs = record_order;
    years(numrecs+1) = year_lc;
    if year_lc = . then years(numrecs+1) = 1900;  /* set to unrealistically low value, so we get   */
                                                  /* negative survival time - all will be 9 filled */
    months(numrecs+1) = month_lc;
    days(numrecs+1) = day_lc;
    if month_lc = . or day_lc = . then missing_lc = 1;
    else missing_lc = 0;
    missings(numrecs+1) = missing_lc;

    /* pass 1, fix any missing days when month is known */
    do i = 1 to numrecs+1;
      if (i = 1) then do;
        if (years(i)=f_year_bt and months(i)=f_month_bt and f_day_bt^=.) then day_start_constraint=f_day_bt;
        else day_start_constraint = 1;
      end;
      if months(i) ^= . then do;
        if months(i) in (1,3,5,7,8,10,12) then number_days_in_month = 31;
        else if months(i) in (4,6,9,11) then number_days_in_month = 30;
        else do;  /* Feb - get last day of Feb in current year by looking at day before March 1 */
          number_days_in_month = day(mdy(3,1,years(i)) - 1);
          end;
        end;
      day_end_constraint = number_days_in_month;
      bdone = 0;
      j = i+1;
      if i > 1 then do;
        if years(i) = years(i-1) and months(i) = months(i-1) then day_start_constraint = days(i-1);
        else day_start_constraint = 1;
        end;
      if months(i) ^= . and days(i) = . then do; /* missing day but not month */
        do until (bdone = 1);
          if years(i) ^= years(j) or months(i) ^= months(j) then bdone = 1;
          else if days(j) ^= . then do;
            day_end_constraint = days(j);
            bdone = 1;
            end;
          if j = numrecs + 1 then bdone = 1;
          j = j+1;
          end; /* end do until */
        days(i) = floor((day_start_constraint + day_end_constraint)/2);
        end;
      end;
    /* pass 2, fix any missing months (and days) - all dates with known month will now have complete date */
    day_start_constraint = 1;
    /* SMS - 9/16/2019 - changed year_dx to years(1) to fix problem with unknown DX month in birth or year when */
    /* person has multiple records - and not all are in year of birth.  Was not using month of birth as constraint */
    if (years(1)=year_bt and month_bt^=.) then do;
    	 month_start_constraint=month_bt;
    	 if (day_bt^=.) then day_start_constraint=day_bt;
    	end;
    else month_start_constraint = 1;
    do i = 1 to numrecs+1;
      day_end_constraint = 31;
      month_end_constraint = 12;
      bdone = 0;
      j = i+1;
      if i > 1 then do;
        if years(i) = years(i-1) then do;
          day_start_constraint = days(i-1);
          month_start_constraint = months(i-1);
          end;
        else do;
          day_start_constraint = 1;
          month_start_constraint = 1;
          end;
        end;
      if months(i) = . then do;
        do until (bdone = 1);
          if years(i) ^= years(j) then bdone = 1;
          else if months(j) ^= . then do;
            day_end_constraint = days(j);
            month_end_constraint = months(j);
            bdone = 1;
            end;
          if j = numrecs + 1 then bdone = 1;
          j = j+1;
          end; /* end do until */
        tempstart = mdy(month_start_constraint, day_start_constraint, years(i));
        tempend = mdy(month_end_constraint, day_end_constraint, years(i));
        newdate = floor((tempstart+tempend)/2);
        months(i) = month(newdate);
        days(i) = day(newdate);
        end;
      end;
    end;
run;

proc sort data = all;
  by state pat_id DESCENDING record_order;
run;

data all;
  set all;
  by state pat_id;
  retain index_lc missing1-missing50 year1-year50 month1-month50 day1-day50 n_missing1-n_missing50 n_year1-n_year50 n_month1-n_month50 n_day1-n_day50 year_lc month_lc day_lc;
  drop missing1-missing50 year1-year50 month1-month50 day1-day50 n_missing1-n_missing50 n_year1-n_year50 n_month1-n_month50 n_day1-n_day50;
  array missings(50) missing1-missing50;
  array years(50) year1-year50;
  array months(50) month1-month50;
  array days(50) day1-day50;
  array n_missings(50) n_missing1-n_missing50;
  array n_years(50) n_year1-n_year50;
  array n_months(50) n_month1-n_month50;
  array n_days(50) n_day1-n_day50;
  if first.pat_id then do;
    index_lc = numrecs + 1;
    do i = 1 to numrecs+1;
      n_missings(i) = missings(i);
      n_years(i) = years(i);
      n_months(i) = months(i);
      n_days(i) = days(i);
      end;
    end;
  missing_dx = n_missings(record_order);
  year_dx = n_years(record_order);
  month_dx = n_months(record_order);
  day_dx = n_days(record_order);
  missing_lc = n_missings(index_lc);
  year_lc = n_years(index_lc);
  month_lc = n_months(index_lc);
  day_lc = n_days(index_lc);
  pa_surv_days = mdy(month_lc, day_lc, year_lc) - mdy(month_dx, day_dx, year_dx);
  pa_surv_mon = floor(pa_surv_days/&DAYS_IN_MONTH);
  if pa_surv_flag=. then do;
  if missing_dx = 1 or missing_lc = 1 then do;
  if year_dx = year_lc and vit_stat ^= 1 and (o_month_dx = o_month_lc or o_month_dx = . or o_month_lc = .) then pa_surv_flag = 2; /* some unknown - could be 0 days */
    else if year_dx = year_lc and vit_stat = 1 and (o_month_dx = month_lc or o_month_dx = .) then pa_surv_flag = 2; /* some unknown - could be 0 days  - don't check orig lc date for alive */
    else pa_surv_flag = 3; /* some unknown - can't be 0 days */
    end;
  else do;
    if pa_surv_days = 0 then pa_surv_flag = 0; /* complete dates, 0 days */
    else pa_surv_flag = 1; /* complete dates, not 0 days */
    end;
  end;
run;

proc sort data = all;
  by state pat_id DESCENDING record_order;
run;

/* Fix issue where person could have one dx with some missing coded as "could be 0 days" followed by */
/* a tumor that could not be zero days (with or without some missing) - therefore the earlier tumor  */
/* can't be 0 days.                                                                                  */
data all;
  set all;
  by state pat_id;
  retain bAny1or3Flags bAny1or3PAFlags;
  if first.pat_id then do;
    bAny1or3Flags = 0;
    bAny1or3PAFlags = 0;
    end;
  if year_dx > &STUDYCUTOFFYEAR then do; /* version 2.9 - added to preserve flags from version 2.8 */
    surv_flag    = 9;
    pa_surv_flag = 9;
    end;
  if surv_flag in(1,3) then bAny1or3Flags = 1;
  if pa_surv_flag in(1,3) then bAny1or3PAFlags = 1;
  if surv_flag = 2 and bAny1or3Flags = 1 then surv_flag = 3;
  if pa_surv_flag = 2 and bAny1or3PAFlags = 1 then pa_surv_flag = 3;
run;

/* sort by original input order - as read from file */
proc sort data = all;
  by order;
run;

/* For inspecting assignment of values for missings */
/* sort by original input order - as read from file */
/*
proc sort data = all;
  by state pat_id record_order;
run;

data single mult;
  set all;
  if numrecs = 1 then output single;
  else output mult;
run;

proc freq data = all;
  tables month_dx day_dx month_lc day_lc;
  title "all records - post fix";
run;

proc freq data = all;
  where (year_dx < &STUDYCUTOFFYEAR);
  tables month_dx day_dx month_lc day_lc;
  title "all records dx prior to study cut-off - post fix";
run;

proc freq data = all;
  where (year_dx >= &STUDYCUTOFFYEAR);
  tables month_dx day_dx month_lc day_lc;
  title "all records dx after study cut-off - post fix";
run;

proc print data = all;
  where (conflict_lc = 1);
  var pat_id record_order month_dx day_dx year_dx month_lc day_lc year_lc o_month_lc o_day_lc o_year_lc o_month_dx surv_days surv_mon surv_flag pa_surv_days pa_surv_mon pa_surv_flag missing_dx missing_lc vit_stat_rec vit_stat;
  title "patients with conflicts in date of last contact or vital status";
run;

proc print data = single;
  where (year_dx = year_lc) and ((o_month_lc = . or o_month_dx = .) or (month_lc = month_dx));
  var month_dx day_dx year_dx month_lc day_lc year_lc o_year_lc o_month_dx o_month_lc surv_days surv_mon surv_flag pa_surv_days pa_surv_mon pa_surv_flag missing_dx missing_lc;
  title "single record - where year dx = year lc and either month was missing";
run;

proc print data = mult;
  var pat_id record_order month_dx day_dx year_dx month_lc day_lc year_lc o_year_lc o_month_dx o_month_lc surv_days surv_mon surv_flag pa_surv_mon pa_surv_flag;
  title "multiple records";
run;

proc sort data = all;
  by order;
run;
*/

data all;
  merge all fullrec;
  by order;
run;

proc sort data = all;
  by state pat_id record_order;
run;

data _null_;
  set all;
  file out lrecl=4048 pad;
  /* put out full record and 4 new fields */
  /* DCO and Autopsy only cases */
  if rept_src in(6,7) then do;  /* Version 2.3 moved this before the next block to match Java - if dco/autopsy and dx after cutoff, flags will be 9, previously 8 */
    surv_mon     = 9999;
    surv_flag    = 8;
    pa_surv_mon  = 9999;
    pa_surv_flag = 8;
    end;
  if year_dx > &STUDYCUTOFFYEAR then do;
    surv_mon     = 9999;
    surv_flag    = 9;
    pa_surv_mon  = 9999;
    pa_surv_flag = 9;
    /* version 2.9 - added code to set date dx missing */
    /* early versions also set it to missing, but it was done earlier in the code.  That had to be removed to make the fix for this version, so it is done here now */
    year_dx=.;  
    month_dx=.; 
    day_dx=.;   
    end;
  if surv_mon < 0 or surv_mon = . then do;
    surv_mon     = 9999;
    surv_flag    = 9;
    end;
  if pa_surv_mon < 0 or pa_surv_mon = . then do;
    pa_surv_mon     = 9999;
    pa_surv_flag    = 9;
    end;

if o_year_dx=. then do;
	year_dx=.;
	month_dx=.; /* changed version 2.3 (was setting to orig_month_dx) */
	day_dx=.;   /* changed version 2.3 (was setting to orig_day_dx)   */
end;

if year_lc=1900 then do;
	 year_lc=orig_year_lc;
	 month_lc=orig_month_lc;
	 day_lc=orig_day_lc;
	end;
if fixed_year_lc=1900 then do;
	 fixed_year_lc=orig_year_lc;
	 fixed_month_lc=orig_month_lc;
	 fixed_day_lc=orig_day_lc;
	end;
/* if conflict in date of last contact or vital status, then 9 fill survival times and flags and blank out dates */
if conflict_lc then do;
    surv_mon       = 9999;
    surv_flag      = 9;
    pa_surv_mon    = 9999;
    pa_surv_flag   = 9;
    fixed_year_lc  = .;
    fixed_month_lc = .;
    fixed_day_lc   = .;
    year_lc        = .;
    month_lc       = .;
    day_lc         = .;
    year_dx        = .;
    month_dx       = .;
    day_dx         = .;
  end;

  if &Excludedays=1 then do;
    put @   1 record      $char4048.
        @ 550 "  " /* orig day dx */
        @2781 "  " /* orig day lc */
        @ 232 "  " /* orig day bt */
        @2798 record_order       z2.
        @2786 vit_stat_rec        1.
        @2965 fixed_year_lc      z4.   /* lc not presumed alive */
        @2969 fixed_month_lc     z2.
        @2971 "  "                     /* day lc */
        @2973 surv_flag           1.
        @2974 surv_mon           z4.
        @2978 year_lc            z4.   /* lc for presumed alive */
        @2982 month_lc           z2.
        @2984 "  "                     /* day lc presumed alive */
        @2986 pa_surv_flag        1.
        @2987 pa_surv_mon        z4.
        @2991 year_dx            z4.   /* dx  */
        @2995 month_dx           z2.
        @2997 "  "                     /* day dx */
        ;
    end;
  else do;
    put @   1 record      $char4048.
        @2798 record_order       z2.
        @2786 vit_stat_rec        1.
        @2965 fixed_year_lc      z4.   /* lc not presumed alive */
        @2969 fixed_month_lc     z2.
        @2971 fixed_day_lc       z2.
        @2973 surv_flag           1.
        @2974 surv_mon           z4.
        @2978 year_lc            z4.   /* lc for presumed alive */
        @2982 month_lc           z2.
        @2984 day_lc             z2.
        @2986 pa_surv_flag        1.
        @2987 pa_surv_mon        z4.
        @2991 year_dx            z4.   /* dx  */
        @2995 month_dx           z2.
        @2997 day_dx             z2.
        ;
    end;
run;