/****** Object:  StoredProcedure [dbo].[sp_ScheduleGetSchedules]    Script Date: 12/1/2020 7:50:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_ScheduleGetSchedules]
@guardianUId INTEGER=0,
@IsHomePage INTEGER=0,
@clientID INTEGER=0,
@prids Integer=null,
@getAll INTEGER=0,
@getAllProvider INTEGER=0,
@companyClientID INTEGER=null,
@providerId integer=null,
@startDate DateTime,
@endDate DateTime,
@IsAdmin integer=null
AS
BEGIN
if @IsAdmin>0
Begin
select c.clwEm as ClientEmail,c.clwPh as ClientPhoneNumber, sh.id, c.fn as client_fn, c.ln as client_ln, s.name as service_name,
cl.ad1, cl.ad2, cl.cty, cl.st, cl.zip,
sh.start_date,c.clsvID as client_ID,sh.serviceId as service_ID,sh.providerId as provider_ID,
sh.end_date,sh.rec_type,sh.is_active, sh.event_pid, sh.event_length, sh.text from Schedules sh
join Clients c on sh.clientId=c.clsvID join CompanyServices s on sh.serviceId=s.serviceId
left join ClientLocationsLookup cll on cll.clsvid = c.clsvID
left join ClientLocations cl on cl.clLocId = cll.cllocId
 where sh.deleted != 1 and  (isnull(@companyClientID, 0)=0 OR sh.clientId=@companyClientID) and (isnull(@providerId, 0)=0 OR  sh.providerId=@providerId) 
End
else if @getAll>0
Begin
--Get Schedules For Emp Portal
WITH StaffList AS        (SELECT S1.ln+' '+S1.fn AS nm,S1.prid,S1.deleted,1 AS eL        FROM Staff AS S1        WHERE prid=@prids        UNION ALL        SELECT S2.ln+' '+S2.fn AS nm,S2.prid,S2.deleted,SL.eL+1 AS eL        FROM Staff AS S2        JOIN StaffList AS SL ON S2.supPrid=SL.prId OR S2.tempsupPrid=SL.prId        WHERE S2.prid<>0 AND S2.prID IS NOT NULL        )select c.clwEm as ClientEmail,c.clwPh as ClientPhoneNumber, sh.id, c.fn as client_fn, c.ln as client_ln, s.name as service_name, sh.start_date, c.clsvID as client_ID,sh.serviceId as service_ID,sh.providerId as provider_ID,
cl.ad1, cl.ad2, cl.cty, cl.st, cl.zip,
sh.end_date,sh.rec_type,sh.is_active, sh.event_pid, sh.event_length, sh.text from Schedules sh
join Clients c on sh.clientId=c.clsvID join CompanyServices s on sh.serviceId=s.serviceId
left join ClientLocationsLookup cll on cll.clsvid = c.clsvID
left join ClientLocations cl on cl.clLocId = cll.cllocId
 where sh.deleted=0 and  (isnull(@companyClientID, 0)=0 OR sh.clientId=@companyClientID) and (isnull(@providerId, 0)=0 OR sh.providerId=@providerId)  and sh.providerId in(SELECT DISTINCT prId        FROM StaffList)  order by sh.start_date asc
 END

else if @clientID>0
Begin
--Get Schedules For Guardian Portal clint filter
select c.clwEm as ClientEmail,c.clwPh as ClientPhoneNumber, sh.id, c.fn as client_fn, c.ln as client_ln, s.name as service_name, sh.start_date,c.clsvID as client_ID,sh.serviceId as service_ID,sh.providerId as provider_ID,
cl.ad1, cl.ad2, cl.cty, cl.st, cl.zip,
sh.end_date,sh.rec_type,sh.is_active, sh.event_pid, sh.event_length, sh.text from Schedules sh
join Clients c on sh.clientId=c.clsvID join CompanyServices s on sh.serviceId=s.serviceId
left join ClientLocationsLookup cll on cll.clsvid = c.clsvID
left join ClientLocations cl on cl.clLocId = cll.cllocId
 where sh.guardianUId=@guardianUId and sh.deleted=0 and c.clsvID=@clientID order by sh.start_date asc
 End

else if @IsHomePage>0
Begin
--Get Schedules For Guardian Portal home page only 10 records
select top 10 c.clwEm as ClientEmail,c.clwPh as ClientPhoneNumber, sh.id, c.fn as client_fn, c.ln as client_ln, s.name as service_name, sh.start_date,c.clsvID as client_ID,sh.serviceId as service_ID,sh.providerId as provider_ID,
cl.ad1, cl.ad2, cl.cty, cl.st, cl.zip,
sh.end_date,sh.rec_type,sh.is_active, sh.event_pid, sh.event_length, sh.text from Schedules sh
join Clients c on sh.clientId=c.clsvID join CompanyServices s on sh.serviceId=s.serviceId
left join ClientLocationsLookup cll on cll.clsvid = c.clsvID
left join ClientLocations cl on cl.clLocId = cll.cllocId
 where sh.guardianUId=@guardianUId and sh.start_date>=getdate() and sh.deleted=0 and sh.end_date<=getdate()+10 order by sh.start_date asc
 End

 ELSE
 Begin
 --Get Schedules For Guardian Portal all schedules
  select c.clwEm as ClientEmail,c.clwPh as ClientPhoneNumber, sh.id, c.fn as client_fn, c.ln as client_ln, s.name as service_name, sh.start_date,c.clsvID as client_ID,sh.serviceId as service_ID,sh.providerId as provider_ID,
  cl.ad1, cl.ad2, cl.cty, cl.st, cl.zip,
sh.end_date,sh.rec_type,sh.is_active, sh.event_pid, sh.event_length, sh.text from Schedules sh
join Clients c on sh.clientId=c.clsvID join CompanyServices s on sh.serviceId=s.serviceId
left join ClientLocationsLookup cll on cll.clsvid = c.clsvID
left join ClientLocations cl on cl.clLocId = cll.cllocId
 where sh.guardianUId=@guardianUId and sh.deleted=0 order by sh.start_date asc
 End

END



