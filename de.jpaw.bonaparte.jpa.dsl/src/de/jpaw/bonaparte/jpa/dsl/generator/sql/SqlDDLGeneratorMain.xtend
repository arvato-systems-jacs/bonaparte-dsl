 /*
  * Copyright 2012 Michael Bischoff
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
  * You may obtain a copy of the License at
  *
  *   http://www.apache.org/licenses/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the License for the specific language governing permissions and
  * limitations under the License.
  */

package de.jpaw.bonaparte.jpa.dsl.generator.sql

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataCategory
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Delimiter
import de.jpaw.bonaparte.jpa.dsl.BDDLPreferences
import de.jpaw.bonaparte.jpa.dsl.bDDL.ColumnNameMappingDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.ElementCollectionRelationship
import de.jpaw.bonaparte.jpa.dsl.bDDL.EmbeddableDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.EmbeddableUse
import de.jpaw.bonaparte.jpa.dsl.bDDL.EntityDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.IndexDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.Inheritance
import de.jpaw.bonaparte.jpa.dsl.bDDL.VectorIndexDefinition
import de.jpaw.bonaparte.jpa.dsl.generator.RequiredType
import de.jpaw.bonaparte.jpa.dsl.generator.YUtil
import java.util.HashSet
import java.util.List
import java.util.Set
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext

import static de.jpaw.bonaparte.jpa.dsl.generator.sql.SqlEnumOut.*
import static de.jpaw.bonaparte.jpa.dsl.generator.sql.SqlEnumOutOracle.*

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.jpa.dsl.generator.YUtil.*
import static extension de.jpaw.bonaparte.jpa.dsl.generator.sql.SqlViewOut.*

class SqlDDLGeneratorMain extends AbstractGenerator {
    static Logger LOGGER = Logger.getLogger(SqlDDLGeneratorMain)

    var int indexCount
    val Set<EnumDefinition> enumsRequired = new HashSet<EnumDefinition>(100)

    var BDDLPreferences prefs

    def makeSqlFilename(EObject e, DatabaseFlavour databaseFlavour, String basename, String object) {
        return "sql/" + databaseFlavour.toString + "/" + object + "/" + basename + ".sql";
    }

    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext unused) {
        prefs = BDDLPreferences.currentPrefs
        LOGGER.info('''Settings are: max ID length = («prefs.maxTablenameLength», «prefs.maxFieldnameLength»), Debug=«prefs.doDebugOut», Postgres=«prefs.doPostgresOut», Oracle=«prefs.doOracleOut», MSSQL=«prefs.doMsSQLServerOut», MySQL=«prefs.doMySQLOut»''')
        enumsRequired.clear
        // SQL DDLs
        for (e : resource.allContents.toIterable.filter(typeof(EntityDefinition))) {
            if (e.noDDL) {
                LOGGER.info("skipping code output of main table for " + e.name)
            } else {
                LOGGER.info("start code output of main table for " + e.name)
                // System::out.println("start code output of main table for " + e.name)
                makeTables(fsa, e, false)
                if (e.tableCategory !== null && e.tableCategory.historyCategory !== null) {
                    // do histories as well
                    LOGGER.info("    doing history table as well, due to category " + e.tableCategory.name);
                    // System::out.println("    doing history table as well, due to category " + e.tableCategory.name);
                    makeTables(fsa, e, true)
                    makeTriggers(fsa, e)
                }
                collectEnums(e)
                makeViews(fsa, e, false, "_nt")
                makeViews(fsa, e, true, "_v")      // enums included, also create a view
                makeElementCollectionTables(fsa, e, false)
            }
        }
        // enum mapping functions
        for (e : enumsRequired) {
            if (prefs.doPostgresOut)
                fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES, e.name, "Function"), postgresEnumFuncs(e))
            if (prefs.doOracleOut)
                fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,   e.name, "Function"), oracleEnumFuncs(e))
            // TODO: HANA + MS SQL
        }
    }

    def private static CharSequence recurseColumns(ClassDefinition cl, ClassDefinition stopAt, DatabaseFlavour databaseFlavour, Delimiter d,
        List<FieldDefinition> pkCols, List<EmbeddableUse> embeddables, ColumnNameMappingDefinition nmd) {
        val pkColumnNames = pkCols?.map[name]  // cannot compare fields, because they might sit in parallel objects
        recurse(cl, stopAt, false,
            [ !properties.hasProperty(PROP_NODDL) ],
              embeddables,
            [ '''-- table columns of java class «name»
              '''],
            [ fld, myName, reqType |
            '''«SqlColumns::doDdlColumn(fld, databaseFlavour, if (pkCols !== null && pkColumnNames.contains(fld.name)) RequiredType::FORCE_NOT_NULL else reqType, d, myName, nmd)»
              ''']
        )
    }


    // recurse through all
    def private void recurseEnumCollection(ClassDefinition c) {
        var ClassDefinition citer = c
        while (citer !== null) {
            for (i : citer.fields) {
                val ref = DataTypeExtension::get(i.datatype)
                if (ref.category == DataCategory.ENUM || ref.category == DataCategory.ENUMALPHA || ref.category == DataCategory.XENUM)
                    enumsRequired.add(ref.enumForEnumOrXenum)
            }
            if (citer.extendsClass !== null)
                citer = citer.extendsClass.classRef
            else
                citer = null
        }
    }

    def private void makeElementCollectionTables(IFileSystemAccess2 fsa, EntityDefinition e, boolean doHistory) {
        for (ec : e.elementCollections) {
            if (doHistory && ec.historytablename === null) {
                // no history here
            } else {
                val tablename = if (doHistory) ec.historytablename else ec.tablename
                if (prefs.doPostgresOut)
                    fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES,    tablename, "Table"), e.sqlEcOut(ec, tablename, DatabaseFlavour::POSTGRES, doHistory))
                if (prefs.doMsSQLServerOut)
                    fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::MSSQLSERVER, tablename, "Table"), e.sqlEcOut(ec, tablename, DatabaseFlavour::MSSQLSERVER, doHistory))
                if (prefs.doMySQLOut)
                    fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::MYSQL,       tablename, "Table"), e.sqlEcOut(ec, tablename, DatabaseFlavour::MYSQL, doHistory))
                if (prefs.doOracleOut) {
                    fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,      tablename, "Table"), e.sqlEcOut(ec, tablename, DatabaseFlavour::ORACLE, doHistory))
                    fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,      tablename, "Synonym"), tablename.sqlSynonymOut)
                }
                if (prefs.doSapHanaOut)
                    fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::SAPHANA,     tablename, "Table"), e.sqlEcOut(ec, tablename, DatabaseFlavour::SAPHANA, doHistory))
            }
        }
    }

    // collect enums for an embeddable, these can be nested
    def private void collectEnums(EmbeddableDefinition e) {
        recurseEnumCollection(e.pojoType)
        for (emb : e.embeddables)
            collectEnums(emb.name)
    }

    def private void collectEnums(EntityDefinition e) {
        recurseEnumCollection(e.tableCategory.trackingColumns)
        recurseEnumCollection(e.pojoType)
        recurseEnumCollection(e.tenantClass)
        // if e contains embeddables, then output enums for these as well
        for (emb : e.embeddables)
            collectEnums(emb.name)
    }

    def private void makeViews(IFileSystemAccess2 fsa, EntityDefinition e, boolean withTracking, String suffix) {
        val tablename = mkTablename(e, false) + suffix
        if (prefs.doOracleOut)
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,   tablename, "View"), e.createView(DatabaseFlavour::ORACLE, withTracking, suffix))
        if (prefs.doPostgresOut)
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES, tablename, "View"), e.createView(DatabaseFlavour::POSTGRES, withTracking, suffix))
    }

    def private void makeTriggers(IFileSystemAccess2 fsa, EntityDefinition e) {
        val tablename = mkTablename(e, false)
        if (prefs.doOracleOut)
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,   tablename + "_tr", "Trigger"), SqlTriggerOut.triggerOutOracle(e))
        if (prefs.doPostgresOut)
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES, tablename + "_tr", "Trigger"), SqlTriggerOut.triggerOutPostgres(e))
    }

    def private void makeTables(IFileSystemAccess2 fsa, EntityDefinition e, boolean doHistory) {
        val tablename = mkTablename(e, doHistory)
        val doSequenceForPk = !doHistory && !e.isAbstract && e.extends === null && e.pk !== null
          && e.pk.columnName.size == 1 && e.pk.columnName.get(0).JavaDataTypeNoName(true).toLowerCase == 'long'
        val sequencename = tablename + "_s"
        // System::out.println("    tablename is " + tablename);
        if (prefs.doPostgresOut) {
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES,    tablename, "Table"), e.sqlDdlOut(DatabaseFlavour::POSTGRES, doHistory))
            if (doSequenceForPk) {
                fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES, sequencename, "Sequence"), SqlSequenceOut.createSequence(sequencename, DatabaseFlavour::POSTGRES))
            }
        }
        if (prefs.doMsSQLServerOut) {
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::MSSQLSERVER, tablename, "Table"), e.sqlDdlOut(DatabaseFlavour::MSSQLSERVER, doHistory))
            if (doSequenceForPk) {
                fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::MSSQLSERVER, sequencename, "Sequence"), SqlSequenceOut.createSequence(sequencename, DatabaseFlavour::MSSQLSERVER))
            }
        }
        if (prefs.doMySQLOut) {
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::MYSQL,       tablename, "Table"), e.sqlDdlOut(DatabaseFlavour::MYSQL, doHistory))
            if (doSequenceForPk) {
                fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::MYSQL,   sequencename, "Sequence"), SqlSequenceOut.createSequence(sequencename, DatabaseFlavour::MYSQL))
            }
        }
        if (prefs.doOracleOut) {
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,      tablename, "Table"), e.sqlDdlOut(DatabaseFlavour::ORACLE, doHistory))
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,      tablename, "Synonym"), tablename.sqlSynonymOut)
            if (doSequenceForPk) {
                fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,  sequencename, "Sequence"), SqlSequenceOut.createSequence(sequencename, DatabaseFlavour::ORACLE))
                fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,  sequencename, "Synonym"), sequencename.sqlSynonymOut)
            }
        }
        if (prefs.doSapHanaOut) {
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::SAPHANA,     tablename, "Table"), e.sqlDdlOut(DatabaseFlavour::SAPHANA, doHistory))
            if (doSequenceForPk) {
                fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::SAPHANA, sequencename, "Sequence"), SqlSequenceOut.createSequence(sequencename, DatabaseFlavour::SAPHANA))
            }
        }
    }

    def private static CharSequence writeFieldSQLdoColumn(FieldDefinition f, DatabaseFlavour databaseFlavour, RequiredType reqType, Delimiter d, List<EmbeddableUse> embeddables, ColumnNameMappingDefinition nmd) {
        writeFieldWithEmbeddedAndList(f, embeddables, null, null, reqType, false, "", [ fld, myName, reqType2 | SqlColumns.doDdlColumn(fld, databaseFlavour, reqType2, d, myName, nmd) ])
    }

    def doDiscriminator(EntityDefinition t, DatabaseFlavour databaseFlavour) {
        if (t.discriminatorTypeInt) {
            switch (databaseFlavour) {
            case DatabaseFlavour::POSTGRES:     return '''«t.discname» integer DEFAULT 0 NOT NULL'''
            case DatabaseFlavour::ORACLE:       return '''«t.discname» number(9) DEFAULT 0 NOT NULL'''
            case DatabaseFlavour::MSSQLSERVER:  return '''«t.discname» int DEFAULT 0 NOT NULL'''
            case DatabaseFlavour::MYSQL:        return '''«t.discname» integer DEFAULT 0 NOT NULL'''
            case DatabaseFlavour::SAPHANA:      return '''«t.discname» integer DEFAULT 0 NOT NULL'''
            }
        } else if (t.discriminatorTypeChar) {
            switch (databaseFlavour) {
            case DatabaseFlavour::POSTGRES:     return '''«t.discname» varchar(1) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            case DatabaseFlavour::ORACLE:       return '''«t.discname» varchar2(1) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            case DatabaseFlavour::SAPHANA:      return '''«t.discname» nvarchar(1) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            case DatabaseFlavour::MSSQLSERVER:  return '''«t.discname» nvarchar(1) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            case DatabaseFlavour::MYSQL:        return '''«t.discname» varchar(1) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            }
        } else {
            switch (databaseFlavour) {
            case DatabaseFlavour::POSTGRES:     return '''«t.discname» varchar(30) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            case DatabaseFlavour::ORACLE:       return '''«t.discname» varchar2(30) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            case DatabaseFlavour::SAPHANA:      return '''«t.discname» nvarchar(30) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            case DatabaseFlavour::MSSQLSERVER:  return '''«t.discname» nvarchar(30) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            case DatabaseFlavour::MYSQL:        return '''«t.discname» varchar(30) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            }
        }
    }

    def indexCounter() {
        return indexCount = indexCount + 1
    }

    def static sqlSynonymOut(String tablename) '''
        CREATE OR REPLACE PUBLIC SYNONYM «tablename» FOR «tablename»;
    '''

    def sqlEcOut(EntityDefinition t, ElementCollectionRelationship ec, String tablename, DatabaseFlavour databaseFlavour, boolean doHistory) {
        val EntityDefinition baseEntity = t.getInheritanceRoot() // for derived tables, the original (root) table
        var myCategory = t.tableCategory
        if (doHistory)
            myCategory = myCategory.historyCategory
        var String tablespaceData = null
        var String tablespaceIndex = null
        if (SqlMapping::supportsTablespaces(databaseFlavour)) {
            tablespaceData  = mkTablespaceName(t, false, myCategory)
            tablespaceIndex = mkTablespaceName(t, true,  myCategory)
        }
        val nmd = t.nameMapping
        val d = new Delimiter("  ", ", ")
        val optionalHistoryKeyPart = if (doHistory) ''', «myCategory.historySequenceColumn»'''
        val startOfPk =
            if (ec.keyColumns !== null)
                ec.keyColumns.join(', ')
            else if (baseEntity.embeddablePk !== null)
                baseEntity.embeddablePk.name.pojoType.fields.map[name.java2sql(nmd)].join(',')
            else if(baseEntity.pk !== null)
                baseEntity.pk.columnName.map[name.java2sql(nmd)].join(',')
            else
                '???'

        return '''
        -- This source has been automatically created by the bonaparte DSL (bonaparte.jpa addon). Do not modify, changes will be lost.
        -- The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        -- The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git

        CREATE TABLE «tablename» (
            -- base table PK
            «IF baseEntity.pk !== null»
                «FOR c : baseEntity.pk.columnName»
                    «c.writeFieldSQLdoColumn(databaseFlavour, RequiredType::FORCE_NOT_NULL, d, t.embeddables, nmd)»
                «ENDFOR»
            «ENDIF»
            «IF ec.mapKey !== null»
                -- element collection key
                , «ec.mapKey.java2sql(nmd)» «SqlMapping::sqlType(ec, databaseFlavour)» NOT NULL
            «ENDIF»
            «IF doHistory»
                , «SqlMapping.getFieldForJavaType(databaseFlavour, "long", "20")»    «myCategory.historySequenceColumn» NOT NULL
            «ENDIF»
            -- contents field
            «ec.name.writeFieldSQLdoColumn(databaseFlavour, RequiredType::DEFAULT, d, t.embeddables, nmd)»
        )«IF tablespaceData !== null» TABLESPACE «tablespaceData»«ENDIF»;

        ALTER TABLE «tablename» ADD CONSTRAINT «tablename»_pk PRIMARY KEY (
            «startOfPk»«FOR ekc : ec.extraKeyColumns», «ekc»«ENDFOR»«IF ec.mapKey !== null», «ec.mapKey.java2sql(nmd)»«ENDIF»«optionalHistoryKeyPart»
        )«IF tablespaceIndex !== null» USING INDEX TABLESPACE «tablespaceIndex»«ENDIF»;
        '''
    }

    def private String vectorIndexType(DatabaseFlavour databaseFlavour, VectorIndexDefinition vid) {
        if (databaseFlavour != DatabaseFlavour.POSTGRES || vid === null) {
            return ""
        } else {
            return " USING " + vid.vectorIndexType.toString.toLowerCase
        }
    }

    def private String vectorIndexWithClause(DatabaseFlavour databaseFlavour, VectorIndexDefinition vid) {
        if (databaseFlavour != DatabaseFlavour.POSTGRES || vid === null || vid.with === null) {
            return ""
        } else {
            return " WITH (" + vid.with + ")"
        }
    }


    def private CharSequence distanceMetricType(DatabaseFlavour databaseFlavour, VectorIndexDefinition vid, CharSequence columnExpression) {
        if (databaseFlavour != DatabaseFlavour.POSTGRES || vid === null) {
            return columnExpression
        } else {
            switch (vid.distanceMetricType) {
                case COSINE: {
                    return columnExpression + " vector_cosine_ops"
                }
                case L1: {
                    return columnExpression + " vector_l1_ops"
                }
                case MANHATTAN: {
                    return columnExpression + " vector_l1_ops"
                }
                case L2: {
                    return columnExpression + " vector_l2_ops"
                }
                case EUCLIDEAN: {
                    return columnExpression + " vector_l2_ops"
                }
                case HAMMING: {
                    return columnExpression + " bit_hamming_ops"
                }
                case JACCARD: {
                    return columnExpression + " bit_jaccard_ops"
                }
                case NEGATIVE_INNER_PRODUCT: {
                    return columnExpression + " vector_ip_ops"
                }
                default: {
                    return columnExpression
                }
            }
        }
    }

    def sqlDdlOut(EntityDefinition t, DatabaseFlavour databaseFlavour, boolean doHistory) {
        val String tablename = YUtil::mkTablename(t, doHistory)
        val baseEntity = t.inheritanceRoot // for derived tables, the original (root) table
        val myPrimaryKeyColumns = t.primaryKeyColumns
        var myCategory = t.tableCategory
        if (doHistory)
            myCategory = myCategory.historyCategory
        var String tablespaceData = null
        var String tablespaceIndex = null
        val ClassDefinition stopAt = if (t.inheritanceRoot.xinheritance == Inheritance::JOIN) t.^extends?.pojoType else null // stop column recursion for JOINed tables
        if (SqlMapping::supportsTablespaces(databaseFlavour)) {
            tablespaceData  = mkTablespaceName(t, false, myCategory)
            tablespaceIndex = mkTablespaceName(t, true,  myCategory)
        }
        val theEmbeddables = t.theEmbeddables
        val nmd = t.nameMapping
        // System::out.println("      tablename is " + tablename);
        // System::out.println('''ENTITY «t.name» (history? «doHistory», DB = «databaseFlavour»): embeddables used are «theEmbeddables.map[name.name + ':' + field.name].join(', ')»''');
        val optionalHistoryKeyPart = if (doHistory) ''', «myCategory.historySequenceColumn»'''

        val tenantClass = if (t.tenantInJoinedTables || t.inheritanceRoot.xinheritance == Inheritance::TABLE_PER_CLASS)
            baseEntity.tenantClass
        else
            t.tenantClass  // for joined tables, only repeat the tenant if the DSL says so

        var grantGroup = myCategory.grantGroup
        val d = new Delimiter("  ", ", ")
        indexCount = 0
        return '''
        -- This source has been automatically created by the bonaparte DSL (bonaparte.jpa addon). Do not modify, changes will be lost.
        -- The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        -- The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git

        CREATE TABLE «tablename» (
            «IF stopAt === null»
                «t.tableCategory.trackingColumns?.recurseColumns(null, databaseFlavour, d, myPrimaryKeyColumns, theEmbeddables, nmd)»
            «ENDIF»
            «tenantClass?.recurseColumns(null, databaseFlavour, d, myPrimaryKeyColumns, theEmbeddables, nmd)»
            «IF t.discname !== null»
                «d.get»«doDiscriminator(t, databaseFlavour)»
            «ENDIF»
            «IF myPrimaryKeyColumns !== null && stopAt !== null»
                «FOR c : myPrimaryKeyColumns»
                    «c.writeFieldSQLdoColumn(databaseFlavour, RequiredType::FORCE_NOT_NULL, d, theEmbeddables, nmd)»
                «ENDFOR»
            «ENDIF»
            «IF doHistory»
                «d.get»«myCategory.historySequenceColumn»   «SqlMapping.getFieldForJavaType(databaseFlavour, "long", "20")» NOT NULL
                «d.get»«myCategory.historyChangeTypeColumn»   «SqlMapping.getFieldForJavaType(databaseFlavour, "char", "1")» NOT NULL
            «ENDIF»
            «t.pojoType.recurseColumns(stopAt, databaseFlavour, d, myPrimaryKeyColumns, theEmbeddables, nmd)»
        )«IF tablespaceData !== null» TABLESPACE «tablespaceData»«ENDIF»;

        «IF myPrimaryKeyColumns !== null»
            ALTER TABLE «tablename» ADD CONSTRAINT «tablename»_pk PRIMARY KEY (
                «FOR c : myPrimaryKeyColumns SEPARATOR ', '»«c.name.java2sql(nmd)»«ENDFOR»«optionalHistoryKeyPart»
            )«IF tablespaceIndex !== null» USING INDEX TABLESPACE «tablespaceIndex»«ENDIF»;
        «ENDIF»
        «IF !doHistory»
            «FOR i : t.index»
                CREATE «IF i.isUnique»UNIQUE «ENDIF»INDEX «tablename.indexname(i, indexCounter)» ON «tablename»«vectorIndexType(databaseFlavour, i.vectorIndex)» (
                    «FOR c : i.columns.columnName SEPARATOR ', '»«distanceMetricType(databaseFlavour, i.vectorIndex, writeIndexColumn(c, databaseFlavour, nmd, i.zeroWhenNull))»«ENDFOR»
                )«writePartialIndexClause(i, databaseFlavour, nmd)»«vectorIndexWithClause(databaseFlavour, i.vectorIndex)»«IF i.nullsNotDistinct» NULLS NOT DISTINCT«ENDIF»«IF tablespaceIndex !== null» TABLESPACE «tablespaceIndex»«ENDIF»;
            «ENDFOR»
        «ENDIF»
        «IF grantGroup !== null && grantGroup.grants !== null && databaseFlavour != DatabaseFlavour.MYSQL»
            «FOR g : grantGroup.grants»
                «IF g.permissions !== null && g.permissions.permissions !== null»
                    GRANT «FOR p : g.permissions.permissions SEPARATOR ','»«p.toString»«ENDFOR» ON «tablename» TO «g.roleOrUserName»;
                «ENDIF»
            «ENDFOR»
        «ENDIF»
        «IF databaseFlavour != DatabaseFlavour.MSSQLSERVER && databaseFlavour != DatabaseFlavour.MYSQL»

            «IF stopAt === null»
                «t.tableCategory.trackingColumns?.recurseComments(null, tablename, theEmbeddables, nmd)»
            «ENDIF»
            «tenantClass?.recurseComments(null, tablename, theEmbeddables, nmd)»
            «IF t.discname !== null»
                COMMENT ON COLUMN «tablename».«t.discname» IS 'autogenerated JPA discriminator column';
            «ENDIF»
            «IF doHistory»
                COMMENT ON COLUMN «tablename».«myCategory.historySequenceColumn» IS 'current sequence number of history entry';
                COMMENT ON COLUMN «tablename».«myCategory.historyChangeTypeColumn» IS 'type of change (C=create/insert, U=update, D=delete)';
            «ENDIF»
            «t.pojoType.recurseComments(stopAt, tablename, theEmbeddables, nmd)»
        «ENDIF»
    '''
    }

    // writes a definition for a partial index (currently only supported for POSTGRES databases)
    def CharSequence writePartialIndexClause(IndexDefinition ind, DatabaseFlavour databaseFlavour, ColumnNameMappingDefinition nmd) {
        if (databaseFlavour == DatabaseFlavour.POSTGRES && ind.partialIndex) {
            if (ind.condition !== null) {
                return ''' WHERE «ind.condition»'''
            } else {
                return ''' WHERE «ind.columns.columnName.get(0).name.java2sql(nmd)» IS NOT NULL'''
            }
        } else {
            return ''''''
        }
    }

    // writes a column name for an index. support function based indexes
    def CharSequence writeIndexColumn(FieldDefinition c, DatabaseFlavour databaseFlavour, ColumnNameMappingDefinition nmd, boolean isFunctionBased) {
        val regular = c.name.java2sql(nmd)
        if (isFunctionBased && !c.isNotNullField) {
            val defaulVal = if (SqlMapping.isAnAlphanumericField(c)) "' '" else "0";
            // nullable field with a zeroWhenNull directive on index
            switch (databaseFlavour) {
                case MSSQLSERVER: {
                    return '''ISNULL(«regular», «defaulVal»)'''
                }
                case MYSQL: {
                    return '''IFNULL(«regular», «defaulVal»)''' // also supports COALESCE
                }
                case ORACLE: {
                    return '''NVL(«regular», «defaulVal»)'''
                }
                case POSTGRES: {
                    return '''COALESCE(«regular», «defaulVal»)'''
                }
                case SAPHANA: {
                    return '''IFNULL(«regular», «defaulVal»)'''
                }
            }
        }
        return regular
    }
}
