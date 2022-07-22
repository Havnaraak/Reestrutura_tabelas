<h3>Objetivo</h3>
  Reestruturação de tabelas com inconsistências no DBCC CheckDB
<h3>Utilização</h3>
<p>&nbsp;&nbsp;O Script demanda um pouco mais de dados para execução, para isso é necessário antes de executá-lo, realizar a montagem do Schema do banco de dados inteiro através do Gerador do SQL Server (a base precisa ter as estruturas mais atualizadas possíveis), para isso, basta seguir os seguintes passos:</p>
<br/>
    <ul>
        <li>Abrir o object Explorer do Sql Server, e buscar a base;</li>
        <li>Ao clicar com o botão direito em cima da base, apresentará as opções de contexto;</li>
        <li>Clique em Tasks > Generate Scripts;</li>
        <li>Na primeira página de introdução, basta clicar em Next;</li>
        <li>Na segunda página, selecione a opção "Select specific database objects" e marque a checkbox "Tables" para gerarmos apenas os scripts de tabelas;</li>
        <li>Após clicar em Next, iremos selecionar a opção "Save as script file" e a opção "One script file per object" e selecionar o local de save dos scripts, após isso, clicaremos em Advanced nessa mesma página;</li>
        <li>Na linha "Script for Server Version", busque a versão do SQL que será utilizado para execução do Script, caso não saiba, coloque uma versão um pouco mais antiga;</li>
        <li>Na linha "Types of data to script" deverá ser selecionado a opção "Schema Only";</li>
        <li>No SubMenu "Table/View Options", deverá marcar todas opções;</li>
        <li>Após isso, basta clicar em "OK" e depois em NEXT;</li>
        <li>Depois de gerado todos scripts, é necessário validar dentro deles se há a clausula USE, pois geralmente o gerador passa como parâmetro o USE[BASE UTILIZADA PARA GERAR SCRIPT], sendo necessário remover essa parte;</li>
    </ul>
<p>Depois de realizado esses passos, dentro do script é necessário alterar a variável @SchemasPath (linha 40) para o caminho que foi gerado os scripts do Schema (OBS: É NECESÁRIO PASSAR UM CAMINHO ACESSIVEL PELO SERVIDOR)</p>
