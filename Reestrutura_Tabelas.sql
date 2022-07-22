/*DEFININDO PARÂMETROS DE RETORNO DA CONSULTA*/
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET FMTONLY OFF

GO

IF (Select Count(1) from sys.procedures Where Name = 'CHECKTABLE_WITH_RETURN') = 0 --Valida se a Procedure já existe, caso não, cria a procedure
	BEGIN
		/*PROCEDURE QUE REALIZARÁ O CHECKTABLE E RETORNARÁ O ERRO*/
		EXEC('CREATE PROCEDURE CHECKTABLE_WITH_RETURN (@Table VARCHAR(MAX)) AS 
			DBCC CHECKTABLE (@Table) WITH ALL_ERRORMSGS, NO_INFOMSGS
	
			RETURN @@ERROR');
	END

GO
	
/*DECLARANDO VARIÁVEIS*/
Declare @TableNames1 Table (TableName Varchar(Max), CodInterno int)
Declare @CodInterno1 int
Declare @TableName1 Varchar(Max)
Declare @TableCount1 int
Declare @TableTestName1 Varchar(Max)
Declare @IncosistentTables Table(TableName Varchar(Max), ErrorCount int, InternalCode int)
Declare @SchemasPath Varchar(Max)
Declare @InternalCodeIncosistenceTable int
Declare @Return int
Declare @CodInternoTabela int
Declare @TableName Varchar(Max)
Declare @ColumnNames Table(ColumnName Varchar(Max), CodInterno int)
Declare @CodInternoColuna int
Declare @Columns Varchar(Max)
Declare @NameTempTable Varchar(Max)
Declare @DatabaseRestore Varchar(Max)
Declare @CompletePath Varchar(Max)
Declare @ErrorMessageControl Varchar(Max)


/*DEFINIÇÃO DE VALORES, ALTERAR APENAS A VARIÁVEL TICKET E SCHEMASPATH*/
Set @TableCount1 = (Select Count(1) From INFORMATION_SCHEMA.TABLES)
Set @SchemasPath = '\\NB-HAUBERT\Scripts\SchemaService\' --Necessário conter o \ no final
Set @Columns = ''
Set @ErrorMessageControl = ''

/*Testa o caminho dos schemas*/
Begin Try
	EXEC('DECLARE @TEST Varchar(MAX)
			Set @TEST = (SELECT * FROM OPENROWSET(BULK '+ '''' + @SchemasPath + 'dbo.LocalizaProdutos.Table.sql' + '''' + ' , SINGLE_NCLOB) AS ROW)')
End Try
Begin Catch
	Print 'Erro ao acessar o caminho dos schemas: '
	Set @ErrorMessageControl = Error_Message()
	Print @ErrorMessageControl
End Catch

IF (IsNull(@ErrorMessageControl, 11) = '') -- Executará somente se não houve erro na validação do caminho
	BEGIN
		/*INSERINDO NOME DAS TABELAS DA BASE*/
		Insert Into
			@TableNames1
		Select
			Table_Name,
			ROW_NUMBER() OVER(Order By Table_Name Desc)
		From
			INFORMATION_SCHEMA.TABLES
		Where
			TABLE_SCHEMA = 'dbo'
			and TABLE_TYPE = 'BASE TABLE'

		/*-------------------------------------------*/
		/*REALIZANDO O CHECKTABLE PARA DESCOBRIR QUAIS TABELAS ESTÃO COM PROBLEMA*/
		While (Select Count(1) from @TableNames1) > 0
			Begin

				Set @TableTestName1 = (Select Top (1) TableName from @TableNames1)

				Begin Try
			
					EXEC @Return = CHECKTABLE_WITH_RETURN @TableTestName1;
					IF @Return <> 0
						Begin
							Insert into @IncosistentTables Values (@TableTestName1, @@ERROR, IsNull((Select Max(InternalCode) From @IncosistentTables), 0) + 1)
						End

				End Try
				Begin Catch

					Insert into @IncosistentTables Values (@TableTestName1, @@ERROR, IsNull((Select Max(InternalCode) From @IncosistentTables), 0) + 1);

				End Catch

				Delete from @TableNames1 where TableName = @TableTestName1

			End


		/*-------------------------------------------*/
		/*CRIANDO BACKUP DAS TABELAS E DROPANDO ELAS*/

		Set @InternalCodeIncosistenceTable = (Select Min(InternalCode) From @IncosistentTables) --Definindo valor inicial da contagem do código interno nas tabelas incosistentes

		While @InternalCodeIncosistenceTable <= (Select Max(InternalCode) from @IncosistentTables)
			Begin
				Begin Try

					Set @TableName1 = (Select TableName from @IncosistentTables Where InternalCode = @InternalCodeIncosistenceTable);
		
					EXEC('Select * Into ' + @TableName1 + '_temp'  + ' From ' + @TableName1); -- Faz o backup da tabela original com base no nmr do ticket

					IF(Select Count(1) From Information_Schema.Tables Where TABLE_NAME = Concat(@TableName1,'_temp')) > 0 --Valida Se a tabela de backup existe, caso não tenha, para o script
						EXEC('Drop Table ' + @TableName1);
					ELSE
						Begin
							Print 'A tabela de backup não foi criada, revise o número do ticket e tente novamente'
							break
						End
				End Try
				Begin Catch
					Print 'Ocorreu um erro ao gerar o backup e/ou dropar a tabela: '
					Print @TableName1
					Print Error_Message()
					Break
				End Catch

				Set @InternalCodeIncosistenceTable += 1

			End

		/*-------------------------------------------*/
		/*INICIANDO RECONSTRUÇÃO DAS TABELAS*/

		Set @InternalCodeIncosistenceTable = (Select Min(InternalCode) From @IncosistentTables) -- Resetando contagem do internal code

		While @InternalCodeIncosistenceTable <= (Select Max(InternalCode) from @IncosistentTables)
			Begin
				Set @TableName = (Select TableName From @IncosistentTables where InternalCode = @InternalCodeIncosistenceTable)

				Set @CompletePath = @SchemasPath + 'dbo.' + @TableName + '.Table.sql' --Monta o caminho completo do script

				Begin Try
					EXEC ('DECLARE @QUERY VARCHAR(MAX)
							SET @QUERY = (SELECT * FROM OPENROWSET(BULK ' + ''''+ @CompletePath+ '''' + ', SINGLE_NCLOB)) AS Result
							EXEC (@QUERY)');
				End try
				Begin Catch
					Print 'Erro ao recriar a tabela: '
					Print @TableName
					Print Error_Message()
					Break
				End Catch

				Set @InternalCodeIncosistenceTable += 1
			End

		/*-------------------------------------------*/
		/*INICIANDO PROCESSO DE REINSERÇÃO DE DADOS*/
		Set @InternalCodeIncosistenceTable = (Select Min(InternalCode) From @IncosistentTables) -- Resetando contagem do internal code

		While @InternalCodeIncosistenceTable <= (Select Max(InternalCode) from @IncosistentTables) 
			Begin

				/*Inserindo dados do nome das colunas da tabela*/
				Insert Into
					@ColumnNames
				Select 
					Column_Name,
					Row_Number() Over(Order by Column_Name ASC)
				From 
					INFORMATION_SCHEMA.COLUMNS 
				Where 
					TABLE_NAME = (Select TableName from @IncosistentTables where InternalCode = @InternalCodeIncosistenceTable)



				/*Concatenando nome das colunas em uma string pra utilizar no Insert*/
				While (Select Count(1) from @ColumnNames) > 0
					Begin
						Set @CodInternoColuna = (Select Max(CodInterno) from @ColumnNames)

						if @CodInternoColuna > 1
							Set @Columns = @Columns + (Select ColumnName from @ColumnNames where CodInterno = @CodInternoColuna) + ',';

						if @CodInternoColuna = 1
							Set @Columns = @Columns + (Select ColumnName from @ColumnNames where CodInterno = @CodInternoColuna);

						Delete from @ColumnNames where CodInterno = @CodInternoColuna

					End

				/*Setando nome das tabelas utilizadas nos comandos*/
				Set @TableName = (Select TableName from @IncosistentTables where InternalCode = @InternalCodeIncosistenceTable)
				Set @NameTempTable =  Concat(@TableName , '_temp')

				/*Definindo Identity Insert ON, inserindo dados da temporária para original e dropando a table temporária*/
				Begin Try
					Begin Transaction

						Begin Try
							Exec('Set Identity_Insert ' + @TableName + ' ON;' + ' Insert Into ' + @TableName + '(' + @Columns + ') Select ' + @Columns + ' From ' + @NameTempTable);
							Exec('Set Identity_Insert ' +  @TableName + ' OFF');
						End Try
						Begin Catch
							Exec(' Insert Into ' + @TableName + '(' + @Columns + ') Select ' + @Columns + ' From ' + @NameTempTable)
						End Catch

						Exec('Drop Table ' + @NameTempTable);

					Commit

				End Try
				Begin Catch
					Print 'Ocorreu um erro ao Inserir dados na tabela reconstruida e/ou dropar a tabela de backup da:'
					Print @TableName
					Print Error_Message()
					Print 'Devido à isso as alterações na table não foram realizadas'
					Rollback
				End Catch 


				/*Atualizando dados de loop do while*/
				Set @InternalCodeIncosistenceTable += 1

				Set @Columns = '';
				Set @TableName = '';
			End
		END

/*Reajustando parâmetros*/
SET NOCOUNT OFF
SET ANSI_WARNINGS ON
SET FMTONLY ON