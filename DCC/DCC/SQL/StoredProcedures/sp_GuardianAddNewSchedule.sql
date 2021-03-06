/****** Object:  StoredProcedure [dbo].[sp_GuardianAddNewSchedule]    Script Date: 12/1/2020 8:52:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--exec sp_ClientGetClientsAppointments
ALTER PROCEDURE [dbo].[sp_GuardianAddNewSchedule] 
	@clientId INT=null,
	@serviceId int=null,
	@providerId int=null,
	@startDate datetime=null,
	@endDate datetime=null,
	@eventLength bigint=null,
	@eventPId int=null,
	@recurringType varchar(64)='',
	@text varchar(200)='',
	@id int=null,
	@mode varchar(6)
AS
BEGIN
	IF @mode = 'INSERT'
	BEGIN
		DECLARE @deleted BIT

		IF @recurringType = 'none'
			SET @deleted = 1
		ELSE
			SET @deleted = 0

		INSERT INTO Schedules
		(clientId,serviceId,start_date,end_date,event_length,event_pid,text,rec_type,providerId,is_active,deleted)
		Output Inserted.id
		SELECT @clientId,@serviceId,@startDate,@endDate,@eventLength,@eventPId,@text,@recurringType,@providerId,1,@deleted

		SELECT c.fn, c.ln, cl.ad1, cl.ad2, cl.cty, cl.st, cl.zip
		FROM Clients c
		LEFT JOIN ClientLocationsLookup cll ON cll.clsvid = c.clsvID
		LEFT JOIN ClientLocations cl ON cl.clLocId = cll.cllocId
		WHERE c.clsvID = @clientId
	END
	ELSE IF @mode = 'UPDATE'
	BEGIN
		UPDATE Schedules
		SET clientId=@clientId, serviceId=@serviceId, providerId=@providerId, start_date=@startDate, end_date=@endDate, event_length=@eventLength, event_pid=@eventPId, text=@text, rec_type=@recurringType
		WHERE id=@id

		SELECT @id as id

		SELECT c.fn, c.ln, cl.ad1, cl.ad2, cl.cty, cl.st, cl.zip
		FROM Clients c
		LEFT JOIN ClientLocationsLookup cll ON cll.clsvid = c.clsvID
		LEFT JOIN ClientLocations cl ON cl.clLocId = cll.cllocId
		WHERE c.clsvID = @clientId
	END
	ELSE IF @mode = 'DELETE'
	BEGIN
		UPDATE Schedules
		SET deleted = 1
		WHERE id=@id OR event_pid=@id

		SELECT @id as id

		SELECT c.fn, c.ln, cl.ad1, cl.ad2, cl.cty, cl.st, cl.zip
		FROM Clients c
		LEFT JOIN ClientLocationsLookup cll ON cll.clsvid = c.clsvID
		LEFT JOIN ClientLocations cl ON cl.clLocId = cll.cllocId
		WHERE c.clsvID = @clientId
	END
END
