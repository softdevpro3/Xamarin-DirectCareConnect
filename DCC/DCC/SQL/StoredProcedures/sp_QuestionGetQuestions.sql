USE [THPL]
GO
/****** Object:  StoredProcedure [dbo].[sp_QuestionGetQuestions]    Script Date: 10/7/2019 1:40:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_QuestionGetQuestions]

AS
BEGIN
	SELECT * FROM Question
	JOIN QuestionValues ON QuestionValues.id=Question.valueTypeId
	ORDER BY title ASC

END