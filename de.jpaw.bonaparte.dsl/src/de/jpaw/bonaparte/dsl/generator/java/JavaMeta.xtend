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

package de.jpaw.bonaparte.dsl.generator.java

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataCategory
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Util

import static extension de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import java.util.Map
import de.jpaw.bonaparte.dsl.generator.XUtil

class JavaMeta {
    // defines the maximum number of digits which could be encountered for a given number
    public static final Map<String,Integer> TOTAL_DIGITS = #{ 'byte' -> 3, 'short' -> 5, 'int' -> 10, 'long' -> 19, 'float' -> 9, 'double' -> 15, 'integer' -> 10, 'biginteger' -> 4000 }
    public static final Map<String,Integer> DECIMAL_DIGITS = #{ 'byte' -> 0, 'short' -> 0, 'int' -> 0, 'long' -> 0, 'float' -> 9, 'double' -> 15, 'integer' -> 0, 'biginteger' -> 0 }

    def private static writeFieldPropertyMapName(FieldDefinition f) {
        if (!f.properties.empty)
            return '''field$property$«f.name»'''
        else
            return "null"
    }

    def private static writeFieldPropertyMap(FieldDefinition f) {
        if (!f.properties.empty)
            return '''
                private static final ImmutableMap<String,String> field$property$«f.name» = new ImmutableMap.Builder<String,String>()
                    «FOR p : f.properties»
                        .put("«p.key.name»", "«IF p.value !== null»«Util::escapeString2Java(p.value)»«ENDIF»")
                    «ENDFOR»
                    .build();
            '''
    }

    def private static makeMeta(ClassDefinition d, FieldDefinition i) {
        val comments = '''
        , «IF i.javadoc === null»null«ELSE»"""
        «i.javadoc»
        """«ENDIF», «IF i.regularComment === null»null«ELSE»"""
        «i.regularComment»
        """«ENDIF», «IF i.comment === null»null«ELSE»"«Util.escapeString2Java(i.comment)»"«ENDIF»'''
        val extraComments = ", null, null, null"  // currently do not generate the same entries for extra items

        val ref = DataTypeExtension::get(i.datatype)
        val elem = ref.elementaryDataType
        var String multi
        var String classname
        var String visibility = getFieldVisibility(d, i).getName()
        var String ext = ""  // category specific data
        var String extraItem = null  // category specific data

        if (i.isArray !== null)
            multi = "Multiplicity.ARRAY, IndexType.NONE, " + i.isArray.mincount + ", " + i.isArray.maxcount
        else if (i.isList !== null)
            multi = "Multiplicity.LIST, IndexType.NONE, " + i.isList.mincount + ", " + i.isList.maxcount
        else if (i.isSet !== null)
            multi = "Multiplicity.SET, IndexType.NONE, " + i.isSet.mincount + ", " + i.isSet.maxcount
        else if (i.isMap !== null)
            multi = "Multiplicity.MAP, IndexType." + i.isMap.indexType.toUpperCase + ", " + i.isMap.mincount + ", " + i.isMap.maxcount
        else
            multi = "Multiplicity.SCALAR, IndexType.NONE, 0, 0"

        switch (ref.category) {
        case DataCategory::BASICNUMERIC: {
            classname = "BasicNumericElementaryDataItem"
            val type = ref.javaType.toLowerCase
            val len = if (elem.length > 0) elem.length else TOTAL_DIGITS.get(type)
            val frac = if (elem.length > 0) elem.decimals else DECIMAL_DIGITS.get(type)
            ext = ''', «b2A(ref.effectiveSigned)», «len», «frac», «b2A(ref.effectiveRounding)»'''
        }
        case DataCategory::NUMERIC: {
            classname = "NumericElementaryDataItem"
            ext = ''', «b2A(ref.effectiveSigned)», «elem.length», «elem.decimals», «b2A(ref.effectiveRounding)», «b2A(ref.effectiveAutoScale)»'''
        }
        case DataCategory::STRING: {
            classname = "AlphanumericElementaryDataItem"
            ext = ''', «b2A(ref.effectiveTrim)», «b2A(ref.effectiveTruncate)», «b2A(ref.effectiveAllowCtrls)», «b2A(!elem.name.toLowerCase.equals("unicode"))», «elem.length», «elem.minLength», «s2A(elem.regexp)»'''
        }
        case DataCategory::ENUMALPHA: {
            classname = "EnumDataItem"
            ext = ''', «elem.enumType.name».enum$MetaData()'''
            // separate item for the token
            extraItem = '''
                public static final AlphanumericElementaryDataItem meta$$«i.name»$token = new AlphanumericElementaryDataItem(Visibility.«visibility», «b2A(i.isRequired)», "«i.name»$token", «multi», DataCategory.STRING,
                    "enum", "String", false, «i.isAggregateRequired», «i.writeFieldPropertyMapName»«extraComments», true, false, false, false, «ref.enumMaxTokenLength», 0, null);
            '''
        }
        case DataCategory::ENUM: {
            classname = "EnumDataItem"
            ext = ''', «elem.enumType.name».enum$MetaData()'''
            extraItem = '''
                public static final BasicNumericElementaryDataItem meta$$«i.name»$token = new BasicNumericElementaryDataItem(Visibility.«visibility», «b2A(i.isRequired)», "«i.name»$token", «multi», DataCategory.NUMERIC,
                    "enum", "int", true, «i.isAggregateRequired», «i.writeFieldPropertyMapName»«extraComments», false, 4, 0, false);  // assume 4 digits
            '''
        }
        case DataCategory::XENUM: {
            classname = "XEnumDataItem"
            // separate item for the token. TODO: Do I need this here?
            extraItem = '''
                public static final AlphanumericElementaryDataItem meta$$«i.name»$token = new AlphanumericElementaryDataItem(Visibility.«visibility», «b2A(i.isRequired)», "«i.name»$token", «multi», DataCategory.STRING,
                    "xenum", "String", false, «i.isAggregateRequired», «i.writeFieldPropertyMapName»«extraComments», true, false, false, false, «ref.enumMaxTokenLength», 0, null);
                '''
            ext = ''', «elem.xenumType.name».xenum$MetaData()'''
        }
        case DataCategory::ENUMSETALPHA: {
            classname = "AlphanumericEnumSetDataItem"
            ext = ''', false, false, false, false, «elem.enumsetType.myEnum.name».enum$MetaData().getIds().size(), 0, null, «elem.enumsetType.name».enumset$MetaData()'''
        }
        case DataCategory::ENUMSET: {
            classname = "NumericEnumSetDataItem"
            ext = ''', false, «TOTAL_DIGITS.get(elem.enumsetType.indexType ?: "int")», 0, false, «elem.enumsetType.name».enumset$MetaData()'''
        }
        case DataCategory::XENUMSET: {
            classname = "XEnumSetDataItem"
            ext = ''', false, false, false, false, «elem.length», 0, null, «elem.xenumsetType.name».xenumset$MetaData()'''
        }
        case DataCategory::TEMPORAL: {
            classname = "TemporalElementaryDataItem"
            ext = ''', «elem.length», «elem.doHHMMSS»'''
        }
        case DataCategory::OBJECT: {
            classname = "ObjectReference"
            if (elem !== null) {
                // just "Object" or Element, Array or Json. All the same
                ext = ''', true, "«ref.javaType»", null, null, null'''
            } else {
                val myLowerBound = ref.objectDataType ?: XUtil::getLowerBound(ref.genericsRef) // objectDataType?.extendsClass)
                val meta = if (myLowerBound === null) "null" else '''«myLowerBound.name».class$MetaData()'''
                val myLowerBound2 = ref.secondaryObjectDataType
                val meta2 = if (myLowerBound2 === null) "null" else '''«myLowerBound2.name».class$MetaData()'''
                ext = ''', «b2A(ref.orSuperClass)», "«ref.javaType»", «meta», «meta2», «B2A(ref.orSecondarySuperClass)»'''
            }
        }
        case DataCategory::BINARY: {
            classname = "BinaryElementaryDataItem"
            ext = ''', «elem.length»'''
        }
        default:
            classname = "MiscElementaryDataItem"
        }
        val bonaparteType = if (ref.elementaryDataType !== null) ref.elementaryDataType.name.toLowerCase else "ref"
        return '''
            «extraItem»
            public static final «classname» meta$$«i.name» = new «classname»(Visibility.«visibility», «b2A(i.isRequired)», "«i.metaName ?: i.name»", «multi», DataCategory.«ref.category.name»,
                "«bonaparteType»", "«ref.javaType»", «b2A(ref.isPrimitive)», «i.isAggregateRequired», «i.writeFieldPropertyMapName»«comments»«ext»);
            '''
    }

    def static writeMetaData(ClassDefinition d) {
        val myPackage = getPackage(d)
        val fqParentName = if (d.parent !== null) d.parent.bonPackageName + "." + d.parent.name
        val propertiesInherited = (d.inheritProperties || myPackage.inheritProperties) && d.getParent !== null
        val externalPrefix = if (d.externalType !== null) 'External'
        return '''
            // property map
            private static final ImmutableMap<String,String> property$Map = new ImmutableMap.Builder<String,String>()
                «FOR p : d.properties»
                    .put("«p.key.name»", "«IF p.value !== null»«Util::escapeString2Java(p.value)»«ENDIF»")
                «ENDFOR»
                «FOR f : d.fields»
                    «FOR p : f.properties»
                        .put("«f.name».«p.key.name»", "«IF p.value !== null»«Util::escapeString2Java(p.value)»«ENDIF»")
                    «ENDFOR»
                «ENDFOR»
                .build();

            «IF !d.properties.empty»
                private static final ImmutableMap<String,String> field$property$this = new ImmutableMap.Builder<String,String>()
                «FOR p : d.properties»
                    .put("«p.key.name»", "«IF p.value !== null»«Util::escapeString2Java(p.value)»«ENDIF»")
                «ENDFOR»
                    .build();
            «ENDIF»

            «FOR f : d.fields»
                «f.writeFieldPropertyMap»
            «ENDFOR»

            // my name and revision
            private static final String _PARTIALLY_QUALIFIED_CLASS_NAME = "«getPartiallyQualifiedClassName(d)»";
            private static final String _REVISION = «IF d.revision !== null && d.revision.length > 0»"«d.revision»"«ELSE»null«ENDIF»;
            private static final String _PARENT = «IF (d.extendsClass !== null)»"«getPartiallyQualifiedClassName(d.getParent)»"«ELSE»null«ENDIF»;
            private static final String _BUNDLE = «IF (myPackage.bundle !== null)»"«myPackage.bundle»"«ELSE»null«ENDIF»;
            private static final int PQON$HASH = _PARTIALLY_QUALIFIED_CLASS_NAME.hashCode();
            public static final String my$PQON = _PARTIALLY_QUALIFIED_CLASS_NAME;

            «FOR i : d.fields»
                «makeMeta(d, i)»
            «ENDFOR»

            // private (immutable) List of fields
            private static final ImmutableList<FieldDefinition> my$fields = ImmutableList.<FieldDefinition>of(
                «d.fields.map['''meta$$«name»'''].join(', ')»
            );

            // extended meta data (for the enhanced interface)
            private static final «externalPrefix»ClassDefinition my$MetaData = new «externalPrefix»ClassDefinition(
                «d.name».class,
                «d.isAbstract»,
                «d.isFinal»,
                _PARTIALLY_QUALIFIED_CLASS_NAME,
                _PARENT,
                _BUNDLE,
                Instant.now(),
                «IF (d.parent !== null)»
                    «fqParentName».class$MetaData(),
                «ELSE»
                    null,
                «ENDIF»
                «writeComments(d.javadoc, d.regularComment)»
                // now specific class items
                _REVISION,
                serialVersionUID,
                «d.fields.size»,
                my$fields,
                property$Map,
                «propertiesInherited»,
                «d.effectiveFactoryId»,
                «d.effectiveClassId»,
                MY_RTTI,
                «d.root.immutable»,
                «d.freezable»
                «IF d.externalType !== null»
                    , «d.singleField»,
                    «d.exceptionConverter»,
                    "«d.externalType.qualifiedName»",
                    "«d.bonaparteAdapterClass»"
                «ENDIF»
            );

            «IF !d.abstract»
                // myself (for Compact*Composer and CSV parsers)
                public static final ObjectReference meta$$this = new ObjectReference(
                    Visibility.PUBLIC, false, "this",
                    Multiplicity.SCALAR, IndexType.NONE, 0, 0,
                    DataCategory.OBJECT, "ref", "«d.name»", false, false, «IF !d.properties.empty»field$property$this«ELSE»null«ENDIF»,
                    null, null, null,
                    «!d.final», "«d.name»", my$MetaData, null, null
                );
            «ENDIF»

            // get all the meta data in one go
            static public ClassDefinition class$MetaData() {
                return my$MetaData;
            }

            // some methods intentionally use the $ sign, because use in normal code is discouraged, so we expect no namespace conflicts here
            @Override
            public ClassDefinition ret$MetaData() {
                return my$MetaData;
            }

            «writeCommonMetaData»

            // the metadata instance
            public static enum BClass implements BonaPortableClass<«d.name»> {
                INSTANCE;

                public static BClass getInstance() {
                    return INSTANCE;
                }

                @Override
                public «d.name» newInstance() {
                    «IF d.abstract»
                        throw new UnsupportedOperationException("«d.name» is abstract");
                    «ELSE»
                        return new «d.name»();
                    «ENDIF»
                }

                @Override
                public Class<«d.name»> getBonaPortableClass() {
                    return «d.name».class;
                }

                @Override
                public int getFactoryId() {
                    return «d.effectiveFactoryId»;
                }
                @Override
                public int getId() {
                    «IF d.hazelcastId == 0»
                        return MY_RTTI;        // reuse of the rtti
                    «ELSE»
                        return «d.hazelcastId»;
                    «ENDIF»
                }
                @Override
                public int getRtti() {
                    return MY_RTTI;
                }
                @Override
                public String getPqon() {
                    return _PARTIALLY_QUALIFIED_CLASS_NAME;
                }
                @Override
                public boolean isFreezable() {
                    return «d.freezable»;
                }
                @Override
                public boolean isImmutable() {
                    return «d.root.immutable»;
                }
                @Override
                public String getBundle() {
                    return _BUNDLE;
                }
                @Override
                public String getRevision() {
                    return _REVISION;
                }
                @Override
                public long getSerial() {
                    return serialVersionUID;
                }
                @Override
                public ClassDefinition getMetaData() {
                    return my$MetaData;
                }
                @Override
                public BonaPortableClass<? extends BonaPortable> getParent() {
                    «IF (d.parent !== null)»
                        return «fqParentName».BClass.getInstance();
                    «ELSE»
                        return null;
                    «ENDIF»
                }
                @Override
                public BonaPortableClass<? extends BonaPortable> getReturns() {
                    «IF (d.returnsClassRef !== null)»
                        return «XUtil::getLowerBound(d.returnsClassRef).name».BClass.getInstance();
                    «ELSE»
                        return «IF d.parent !== null»«fqParentName».BClass.getInstance().getReturns()«ELSE»null«ENDIF»;
                    «ENDIF»
                }
                @Override
                public BonaPortableClass<? extends BonaPortable> getPrimaryKey() {
                    «IF (d.recursePkClass !== null)»
                        return «d.recursePkClass.name».BClass.getInstance();
                    «ELSE»
                        return null;
                    «ENDIF»
                }
                @Override
                public ImmutableMap<String,String> getPropertyMap() {
                    return property$Map;
                }
                @Override
                public String getProperty(String id) {
                    «IF propertiesInherited»
                        return property$Map.containsKey(id) ? property$Map.get(id) : «fqParentName».BClass.getInstance().getProperty(id);
                    «ELSE»
                        return property$Map.get(id);
                    «ENDIF»
                }
            }

            @Override
            public BonaPortableClass<? extends BonaPortable> ret$BonaPortableClass() {
                return BClass.getInstance();
            }
            // convenience method for easier access via reflection
            public static BonaPortableClass<? extends BonaPortable> class$BonaPortableClass() {
                return BClass.getInstance();
            }

        '''
    }

    def static writeComments(String javadoc, String regularComment) '''
        «IF javadoc === null»
            null,
        «ELSE»
            """
            «javadoc»
            """,
        «ENDIF»
        «IF regularComment === null»
            null,
        «ELSE»
            """
            «regularComment»
            """,
        «ENDIF»
    '''

    // write the access methods for the interface BonaMeta
    def static writeCommonMetaData() '''
        // convenience functions for faster access if the metadata structure is not used
        @Override
        public String ret$PQON() {
            return _PARTIALLY_QUALIFIED_CLASS_NAME;
        }
        @Override
        public String ret$Parent() {
            return _PARENT;
        }
        @Override
        public String ret$Bundle() {
            return _BUNDLE;
        }
    '''
}
