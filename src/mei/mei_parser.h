
/* A Bison parser, made by GNU Bison 2.4.1.  */

/* Skeleton interface for Bison's Yacc-like parsers in C
   
      Copyright (C) 1984, 1989, 1990, 2000, 2001, 2002, 2003, 2004, 2005, 2006
   Free Software Foundation, Inc.
   
   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.
   
   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */


/* Tokens.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
   /* Put the tokens into the symbol table, so that GDB and other debuggers
      know about them.  */
   enum yytokentype {
     NUMBER = 258,
     VAR = 259,
     FUN1 = 260,
     FUN2 = 261,
     FUN3 = 262,
     FUN4 = 263,
     IN1D = 264,
     WHILE = 265,
     IF = 266,
     PRINT = 267,
     IFX = 268,
     ELSE = 269,
     OR = 270,
     AND = 271,
     NE = 272,
     EQ = 273,
     LE = 274,
     GE = 275,
     UMINUS = 276,
     UPLUS = 277
   };
#endif
/* Tokens.  */
#define NUMBER 258
#define VAR 259
#define FUN1 260
#define FUN2 261
#define FUN3 262
#define FUN4 263
#define IN1D 264
#define WHILE 265
#define IF 266
#define PRINT 267
#define IFX 268
#define ELSE 269
#define OR 270
#define AND 271
#define NE 272
#define EQ 273
#define LE 274
#define GE 275
#define UMINUS 276
#define UPLUS 277




#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
typedef union YYSTYPE
{

/* Line 1676 of yacc.c  */
#line 50 "mei_parser.y"

    double iValue;              /* double value */
    char sIndex[200];           /* variable, constant or function identifier */
    mei_node_t *nPtr;           /* node pointer */



/* Line 1676 of yacc.c  */
#line 104 "mei_parser.h"
} YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define yystype YYSTYPE /* obsolescent; will be withdrawn */
# define YYSTYPE_IS_DECLARED 1
#endif

extern YYSTYPE yylval;


