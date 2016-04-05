-- -*- Mode: Haskell -*-
{
module Forpar.Parser.Fortran90 ( statementParser
                               ) where

import Prelude hiding (EQ,LT,GT) -- Same constructors exist in the AST

import Forpar.Util.Position
import Forpar.ParserMonad
import Forpar.Lexer.FreeForm
import Forpar.AST

import Debug.Trace

}

%name statementParser STATEMENT
%monad { LexAction }
%lexer { lexer } { TEOF _ }
%tokentype { Token }
%error { parseError }

%token
  id                          { TId _ _ }
  comment                     { TComment _ _ }
  string                      { TString _ _ }
  label                       { TLabel _ _ }
  int                         { TIntegerLiteral _ _ }
  float                       { TRealLiteral _ _ }
  boz                         { TBozLiteral _ _ }
  ','                         { TComma _ }
  ';'                         { TSemiColon _ }
  ':'                         { TColon _ }
  '::'                        { TDoubleColon _ }
  '='                         { TOpAssign _ }
  '=>'                        { TArrow _ }
  '%'                         { TPercent _ }
  '('                         { TLeftPar _ }
  ')'                         { TRightPar _ }
  '(/'                        { TLeftInitPar _ }
  '/)'                        { TRightInitPar _ }
  opCustom                    { TOpCustom _ _ }
  '**'                        { TOpExp _ }
  '+'                         { TOpPlus _ }
  '-'                         { TOpMinus _ }
  '*'                         { TStar _ }
  '/'                         { TSlash _ }
  or                          { TOpOr _ }
  and                         { TOpAnd _ }
  not                         { TOpNot _ }
  eqv                         { TOpEquivalent _ }
  neqv                        { TOpNotEquivalent _ }
  '<'                         { TOpLT _ }
  '<='                        { TOpLE _ }
  '=='                        { TOpEQ _ }
  '!='                        { TOpNE _ }
  '>'                         { TOpGT _ }
  '>='                        { TOpGE _ }
  bool                        { TLogicalLiteral _ _ }
  program                     { TProgram _ }
  endProgram                  { TEndProgram _ }
  function                    { TFunction _ }
  endFunction                 { TEndFunction _ }
  result                      { TResult _ }
  recursive                   { TRecursive _ }
  subroutine                  { TSubroutine _ }
  endSubroutine               { TEndSubroutine _ }
  blockData                   { TBlockData _ }
  endBlockData                { TEndBlockData _ }
  module                      { TModule _ }
  endModule                   { TEndModule _ }
  contains                    { TContains _ }
  use                         { TUse _ }
  only                        { TOnly _ }
  interface                   { TInterface _ }
  endInterface                { TEndInterface _ }
  procedure                   { TProcedure _ }
  assignment                  { TAssignment _ }
  operator                    { TOperator _ }
  call                        { TCall _ }
  return                      { TReturn _ }
  public                      { TPublic _ }
  private                     { TPrivate _ }
  parameter                   { TParameter _ }
  allocatable                 { TAllocatable _ }
  dimension                   { TDimension _ }
  external                    { TExternal _ }
  intent                      { TIntent _ }
  intrinsic                   { TIntrinsic _ }
  optional                    { TOptional _ }
  pointer                     { TPointer _ }
  save                        { TSave _ }
  target                      { TTarget _ }
  in                          { TIn _ }
  out                         { TOut _ }
  inout                       { TInOut _ }
  data                        { TData _ }
  namelist                    { TNamelist _ }
  implicit                    { TImplicit _ }
  equivalence                 { TEquivalence _ }
  common                      { TCommon _ }
  allocate                    { TAllocate _ }
  deallocate                  { TDeallocate _ }
  nullify                     { TNullify _ }
  none                        { TNone _ }
  goto                        { TGoto _ }
  assign                      { TAssign _ }
  to                          { TTo _ }
  continue                    { TContinue _ }
  stop                        { TStop _ }
  pause                       { TPause _ }
  do                          { TDo _ }
  endDo                       { TEndDo _ }
  while                       { TWhile _ }
  if                          { TIf _ }
  then                        { TThen _ }
  else                        { TElse _ }
  elsif                       { TElsif _ }
  endif                       { TEndIf _ }
  case                        { TCase _ }
  selectCase                  { TSelectCase _ }
  endSelect                   { TEndSelect _ }
  default                     { TDefault _ }
  cycle                       { TCycle _ }
  exit                        { TExit _ }
  where                       { TWhere _ }
  elsewhere                   { TElsewhere _ }
  endWhere                    { TEndWhere _ }
  type                        { TType _ }
  endType                     { TEndType _ }
  sequence                    { TSequence _ }
  kind                        { TKind _ }
  len                         { TLen _ }
  integer                     { TInteger _ }
  real                        { TReal _ }
  doublePrecision             { TDoublePrecision _ }
  logical                     { TLogical _ }
  character                   { TCharacter _ }
  complex                     { TComplex _ }
  open                        { TOpen _ }
  close                       { TClose _ }
  read                        { TRead _ }
  write                       { TWrite _ }
  print                       { TPrint _ }
  backspace                   { TBackspace _ }
  rewind                      { TRewind _ }
  inquire                     { TInquire _ }
  endfile                     { TEndfile _ }
  end                         { TEnd _ }
  newline                     { TNewline _ }

-- Precedence of operators

-- Level 6
%left opCustom

-- Level 5
%left eqv neqv
%left or
%left and
%right not

-- Level 4
%nonassoc '==' '!=' '>' '<' '>=' '<='
%nonassoc RELATIONAL

-- Level 3
%left CONCAT

-- Level 2
%left '+' '-'
%left '*' '/'
%right SIGN
%right '**'

-- Level 1
%right DEFINED_UNARY

%%

STATEMENT :: { Statement A0 }
: OTHER_EXECUTABLE_STATEMENT { $1 }
| NONEXECUTABLE_STATEMENT { $1 }

OTHER_EXECUTABLE_STATEMENT :: { Statement A0 }
: EXPRESSION_ASSIGNMENT_STATEMENT { $1 }

EXPRESSION_ASSIGNMENT_STATEMENT :: { Statement A0 }
: ELEMENT '=' EXPRESSION { StExpressionAssign () (getTransSpan $1 $3) $1 $3 }

ELEMENT :: { Expression A0 } : VARIABLE { $1 } | SUBSCRIPT { $1 }

NONEXECUTABLE_STATEMENT :: { Statement A0 }
: DECLARATION_STATEMENT { $1 }

DECLARATION_STATEMENT :: { Statement A0 }
: TYPE_SPEC ATTRIBUTE_LIST '::' DECLARATOR_LIST
  { let { attrList = reverse $2;
          mAttrAList =
            if null attrList
              then Nothing
              else Just $ AList () (getSpan attrList) attrList;
          declList = reverse $4;
          declAList = AList () (getSpan declList) declList }
    in StDeclaration () (getTransSpan $1 $4) $1 mAttrAList declAList }
| TYPE_SPEC DECLARATOR_LIST
  { let { declList = reverse $2;
          declAList = AList () (getSpan declList) declList }
    in StDeclaration () (getTransSpan $1 $2) $1 Nothing declAList }

ATTRIBUTE_LIST :: { [ Attribute A0 ] }
: ATTRIBUTE_LIST ',' ATTRIBUTE_SPEC { $3 : $1 }
| {- EMPTY -} { [ ] }

ATTRIBUTE_SPEC :: { Attribute A0 }
: parameter { AttrParameter () (getSpan $1) }
| public { AttrPublic () (getSpan $1) }
| private { AttrPrivate () (getSpan $1) }
| allocatable { AttrAllocatable () (getSpan $1) }
| dimension '(' DIMENSION_DECLARATORS ')'
  { AttrDimension () (getTransSpan $1 $4) $3 }
| external { AttrExternal () (getSpan $1) }
| intent '(' INTENT_CHOICE ')' { AttrIntent () (getTransSpan $1 $4) $3 }
| intrinsic { AttrIntrinsic () (getSpan $1) }
| optional { AttrOptional () (getSpan $1) }
| pointer { AttrPointer () (getSpan $1) }
| save { AttrSave () (getSpan $1) }
| target { AttrTarget () (getSpan $1) }

INTENT_CHOICE :: { Intent } : in { In } | out { Out } | inout { InOut }

DECLARATOR_LIST :: { [ Declarator A0 ] }
: DECLARATOR_LIST ',' INITIALISED_DECLARATOR { $3 : $1 }
| INITIALISED_DECLARATOR { [ $1 ] }

INITIALISED_DECLARATOR :: { Declarator A0 }
: DECLARATOR '=' EXPRESSION { setInitialisation $1 $3 }
| DECLARATOR { $1 }

DECLARATOR :: { Declarator A0 }
: VARIABLE { DeclVariable () (getSpan $1) $1 Nothing Nothing }
| VARIABLE '*' EXPRESSION
  { DeclVariable () (getTransSpan $1 $3) $1 (Just $3) Nothing }
| VARIABLE '*' '(' '*' ')'
  { let star = ExpValue () (getSpan $4) ValStar
    in DeclVariable () (getTransSpan $1 $5) $1 (Just star) Nothing }
| VARIABLE '(' DIMENSION_DECLARATORS ')'
  { DeclArray () (getTransSpan $1 $4) $1 $3 Nothing Nothing }
| VARIABLE '(' DIMENSION_DECLARATORS ')' '*' EXPRESSION
  { DeclArray () (getTransSpan $1 $6) $1 $3 (Just $6) Nothing }
| VARIABLE '(' DIMENSION_DECLARATORS ')' '*' '(' '*' ')'
  { let star = ExpValue () (getSpan $7) ValStar
    in DeclArray () (getTransSpan $1 $8) $1 $3 (Just star) Nothing }

DIMENSION_DECLARATORS :: { AList DimensionDeclarator A0 }
: DIMENSION_DECLARATORS ',' DIMENSION_DECLARATOR
  { setSpan (getTransSpan $1 $3) $ $3 `aCons` $1 }
| DIMENSION_DECLARATOR
  { AList () (getSpan $1) [ $1 ] }

DIMENSION_DECLARATOR :: { DimensionDeclarator A0 }
: EXPRESSION ':' EXPRESSION
  { DimensionDeclarator () (getTransSpan $1 $3) (Just $1) $3 }
| EXPRESSION { DimensionDeclarator () (getSpan $1) Nothing $1 }
| EXPRESSION ':' '*'
  { let { span = getSpan $3;
          star = ExpValue () span ValStar }
    in DimensionDeclarator () (getTransSpan $1 span) (Just $1) star }
| '*'
  { let { span = getSpan $1;
          star = ExpValue () span ValStar }
    in DimensionDeclarator () span Nothing star }

TYPE_SPEC :: { TypeSpec A0 }
: integer KIND_SELECTOR   { TypeSpec () (getSpan ($1, $2)) TypeInteger $2 }
| real    KIND_SELECTOR   { TypeSpec () (getSpan ($1, $2)) TypeReal $2 }
| doublePrecision { TypeSpec () (getSpan $1) TypeDoublePrecision Nothing }
| complex KIND_SELECTOR   { TypeSpec () (getSpan ($1, $2)) TypeComplex $2 }
| character CHAR_SELECTOR { TypeSpec () (getSpan ($1, $2)) TypeCharacter $2 }
| logical KIND_SELECTOR   { TypeSpec () (getSpan ($1, $2)) TypeLogical $2 }
| type '(' id ')'
  { let TId _ id = $3
    in TypeSpec () (getTransSpan $1 $4) (TypeCustom id) Nothing }

KIND_SELECTOR :: { Maybe (Selector A0) }
: '(' EXPRESSION ')'
  { Just $ Selector () (getTransSpan $1 $3) Nothing (Just $2) }
| '(' kind '=' EXPRESSION ')'
  { Just $ Selector () (getTransSpan $1 $5) Nothing (Just $4) }
| {- EMPTY -} { Nothing }

CHAR_SELECTOR :: { Maybe (Selector A0) }
: '*' EXPRESSION
  { Just $ Selector () (getTransSpan $1 $2) (Just $2) Nothing }
-- The following rule is a bug in the spec.
-- | '*' EXPRESSION ','
--   { Just $ Selector () (getTransSpan $1 $2) (Just $2) Nothing }
| '*' '(' '*' ')'
  { let star = ExpValue () (getSpan $3) ValStar
    in Just $ Selector () (getTransSpan $1 $4) (Just star) Nothing }
| '(' EXPRESSION ')'
  { Just $ Selector () (getTransSpan $1 $3) (Just $2) Nothing }
| '(' len '=' EXPRESSION ')'
  { Just $ Selector () (getTransSpan $1 $5) (Just $4) Nothing }
| '(' EXPRESSION ',' EXPRESSION ')'
  { Just $ Selector () (getTransSpan $1 $5) (Just $2) (Just $4) }
| '(' EXPRESSION ',' kind '=' EXPRESSION ')'
  { Just $ Selector () (getTransSpan $1 $7) (Just $2) (Just $6) }
| '(' len '=' EXPRESSION ',' kind '=' EXPRESSION ')'
  { Just $ Selector () (getTransSpan $1 $9) (Just $4) (Just $8) }
| '(' kind '=' EXPRESSION ',' len '=' EXPRESSION ')'
  { Just $ Selector () (getTransSpan $1 $9) (Just $8) (Just $4) }
| {- EMPTY -} { Nothing }

EXPRESSION :: { Expression A0 }
: EXPRESSION '+' EXPRESSION
  { ExpBinary () (getTransSpan $1 $3) Addition $1 $3 }
| EXPRESSION '-' EXPRESSION
  { ExpBinary () (getTransSpan $1 $3) Subtraction $1 $3 }
| EXPRESSION '*' EXPRESSION
  { ExpBinary () (getTransSpan $1 $3) Multiplication $1 $3 }
| EXPRESSION '/' EXPRESSION
  { ExpBinary () (getTransSpan $1 $3) Division $1 $3 }
| EXPRESSION '**' EXPRESSION
  { ExpBinary () (getTransSpan $1 $3) Exponentiation $1 $3 }
| EXPRESSION '/' '/' EXPRESSION %prec CONCAT
  { ExpBinary () (getTransSpan $1 $4) Concatenation $1 $4 }
| ARITHMETIC_SIGN EXPRESSION %prec SIGN
  { ExpUnary () (getTransSpan (fst $1) $2) (snd $1) $2 }
| EXPRESSION or EXPRESSION
  { ExpBinary () (getTransSpan $1 $3) Or $1 $3 }
| EXPRESSION and EXPRESSION
  { ExpBinary () (getTransSpan $1 $3) And $1 $3 }
| not EXPRESSION
  { ExpUnary () (getTransSpan $1 $2) Not $2 }
| EXPRESSION eqv EXPRESSION
  { ExpBinary () (getTransSpan $1 $3) Equivalent $1 $3 }
| EXPRESSION neqv EXPRESSION
  { ExpBinary () (getTransSpan $1 $3) NotEquivalent $1 $3 }
| EXPRESSION RELATIONAL_OPERATOR EXPRESSION %prec RELATIONAL
  { ExpBinary () (getTransSpan $1 $3) $2 $1 $3 }
| opCustom EXPRESSION %prec DEFINED_UNARY {
    let TOpCustom span str = $1
    in ExpUnary () (getTransSpan span $2) (UnCustom str) $2 }
| EXPRESSION opCustom EXPRESSION {
    let TOpCustom _ str = $2
    in ExpBinary () (getTransSpan $1 $3) (BinCustom str) $1 $3 }
| '(' EXPRESSION ')' { setSpan (getTransSpan $1 $3) $2 }
| NUMERIC_LITERAL                   { $1 }
| '(' EXPRESSION ',' EXPRESSION ')'
  { ExpValue () (getTransSpan $1 $5) (ValComplex $2 $4) }
| LOGICAL_LITERAL                   { $1 }
| STRING                            { $1 }
| SUBSCRIPT                         { $1 }
| SUBSTRING                         { $1 }
| VARIABLE                          { $1 }
| IMPLIED_DO                        { $1 }
| '(/' EXPRESSION_LIST '/)' {
    let { exps = reverse $2;
          expList = AList () (getSpan exps) exps }
    in ExpInitialisation () (getTransSpan $1 $3) expList
          }

DO_SPECIFICATION :: { DoSpecification A0 }
: EXPRESSION_ASSIGNMENT_STATEMENT ',' EXPRESSION ',' EXPRESSION
  { DoSpecification () (getTransSpan $1 $5) $1 $3 (Just $5) }
| EXPRESSION_ASSIGNMENT_STATEMENT ',' EXPRESSION
  { DoSpecification () (getTransSpan $1 $3) $1 $3 Nothing }

SUBSTRING :: { Expression A0 }
: SUBSCRIPT '(' EXPRESSION ':' EXPRESSION ')'
  { ExpSubstring () (getTransSpan $1 $6) $1 (Just $3) (Just $5) }
| SUBSCRIPT '(' ':' EXPRESSION ')'
  { ExpSubstring () (getTransSpan $1 $5) $1 Nothing (Just $4) }
| SUBSCRIPT '(' EXPRESSION ':' ')'
  { ExpSubstring () (getTransSpan $1 $5) $1 (Just $3) Nothing }
| SUBSCRIPT '(' ':' ')'
  { ExpSubstring () (getTransSpan $1 $4) $1 Nothing Nothing }
| ARRAY '(' EXPRESSION ':' EXPRESSION ')'
  { ExpSubstring () (getTransSpan $1 $6) $1 (Just $3) (Just $5) }
| ARRAY '(' ':' EXPRESSION ')'
  { ExpSubstring () (getTransSpan $1 $5) $1 Nothing (Just $4) }
| ARRAY '(' EXPRESSION ':' ')'
  { ExpSubstring () (getTransSpan $1 $5) $1 (Just $3) Nothing }
| ARRAY '(' ':' ')'
  { ExpSubstring () (getTransSpan $1 $4) $1 Nothing Nothing }

SUBSCRIPT :: { Expression A0 }
: ARRAY INDICIES { ExpSubscript () (getTransSpan $1 $2) $1 $2 }

INDICIES :: { AList Expression A0 }
: INDICIES_L1 ')' { setSpan (getTransSpan $1 $2) $ aReverse $1 }

INDICIES_L1 :: { AList Expression A0  }
: INDICIES_L1 ',' EXPRESSION { setSpan (getTransSpan $1 $3) $ $3 `aCons` $1 }
| '(' EXPRESSION { AList () (getTransSpan $1 $2) [ $2 ] }
| '(' { AList () (getSpan $1) [ ] }

IMPLIED_DO :: { Expression A0 }
: '(' EXPRESSION ',' DO_SPECIFICATION ')'
  { let expList = AList () (getSpan $2) [ $2 ]
    in ExpImpliedDo () (getTransSpan $1 $5) expList $4 }
| '(' EXPRESSION ',' EXPRESSION ',' DO_SPECIFICATION ')'
  { let expList = AList () (getTransSpan $2 $4) [ $2, $4 ]
    in ExpImpliedDo () (getTransSpan $1 $5) expList $6 }
| '(' EXPRESSION ',' EXPRESSION ',' EXPRESSION_LIST ',' DO_SPECIFICATION ')'
  { let { exps =  reverse $6;
          expList = AList () (getTransSpan $2 exps) ($2 : $4 : reverse $6) }
    in ExpImpliedDo () (getTransSpan $1 $9) expList $8 }

EXPRESSION_LIST :: { [ Expression A0 ] }
: EXPRESSION_LIST ',' EXPRESSION { $3 : $1 }
| EXPRESSION { [ $1 ] }

ARITHMETIC_SIGN :: { (SrcSpan, UnaryOp) }
: '-' { (getSpan $1, Minus) }
| '+' { (getSpan $1, Plus) }

RELATIONAL_OPERATOR :: { BinaryOp }
: '=='  { EQ }
| '!='  { NE }
| '>'   { GT }
| '>='  { GTE }
| '<'   { LT }
| '<='  { LTE }

VARIABLE :: { Expression A0 }
: id { ExpValue () (getSpan $1) $ let (TId _ s) = $1 in ValVariable () s }

ARRAY :: { Expression A0 }
: id { ExpValue () (getSpan $1) $ let (TId _ s) = $1 in ValArray () s }

NUMERIC_LITERAL :: { Expression A0 }
: INTEGER_LITERAL { $1 } | REAL_LITERAL { $1 }

INTEGER_LITERAL :: { Expression A0 }
: int { let TIntegerLiteral s i = $1 in ExpValue () s $ ValInteger i }
| boz { let TBozLiteral s i = $1 in ExpValue () s $ ValInteger i }

REAL_LITERAL :: { Expression A0 }
: float { let TRealLiteral s r = $1 in ExpValue () s $ ValReal r }

LOGICAL_LITERAL :: { Expression A0 }
: bool { let TLogicalLiteral s b = $1 in ExpValue () s $ ValLogical b }

STRING :: { Expression A0 }
: string { let TString s c = $1 in ExpValue () s $ ValString c }

{

type A0 = ()

parseError :: Token -> LexAction a
parseError _ = fail "Parsing failed."

}
