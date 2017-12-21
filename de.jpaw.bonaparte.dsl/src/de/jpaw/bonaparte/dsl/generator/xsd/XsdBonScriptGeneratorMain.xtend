 /*
  * Copyright 2015 Michael Bischoff
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

package de.jpaw.bonaparte.dsl.generator.xsd

import com.google.common.base.Strings
import com.google.inject.Inject
import de.jpaw.bonaparte.dsl.BonScriptPreferences
import de.jpaw.bonaparte.dsl.BonScriptTraceExtensions
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassReference
import de.jpaw.bonaparte.dsl.bonScript.DataType
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.XXmlAccess
import de.jpaw.bonaparte.dsl.bonScript.XXmlFormDefault
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import java.util.HashSet
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.java.JavaEnum.*
import static extension de.jpaw.bonaparte.dsl.generator.java.JavaXEnum.*
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import org.eclipse.xtext.generator.trace.node.Traced
import de.jpaw.bonaparte.dsl.bonScript.XEnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.EnumSetDefinition
import de.jpaw.bonaparte.dsl.bonScript.XEnumSetDefinition

/** Generator which produces xsds.
 * It is only called if XML has not been suppressed in the preferences.
 */
class XsdBonScriptGeneratorMain extends AbstractGenerator {
    public static final String GENERATED_XSD_SUBFOLDER = "resources/xsd/";      // cannot start with a slash, must end with a slash
    public static final String GENERATED_COMMENT = "<!-- autogenerated by bonaparte DSL -->"

    @Inject extension BonScriptTraceExtensions

    private boolean GENERATE_XSD_BY_DEFAULT = true;                // if true, also generate xsds if the class or package does not explicitly specify it
    private boolean ROOT_ELEMENTS_SEPARATE = true;                 // if true, also generate xsds if the class or package does not explicitly specify it
    private boolean SUBFOLDERS_FOR_BUNDLES = false;                // if true, also generate xsds if the class or package does not explicitly specify it
    private boolean GENERATE_EXTENSION_FIELDS = false;             // if true, xsd:anyType fields will be generated in order to support future optional extensions (currently only possible for final classes)

    val Set<PackageDefinition> requiredImports = new HashSet<PackageDefinition>()
    val Set<EObject> visitedMarker = new HashSet<EObject>()

    def private computeRelativePathPrefix(PackageDefinition pkg) {
        if (pkg.bundle === null || !SUBFOLDERS_FOR_BUNDLES)
            return ""
        val buff = new StringBuilder
        var int n = -1;
        val bundle = pkg.bundle
        // compose a sequence of at least one "../", plus an additional for every dot occuring in the bundle ID
        do {
            buff.append("../")
            n = bundle.indexOf('.', n+1)
        } while (n >= 0)
        return buff.toString
    }

    /** Creates the filename to store a generated xsd file in. */
    def private computeXsdFilename(PackageDefinition pkg) {
        if (pkg.bundle === null || !SUBFOLDERS_FOR_BUNDLES)
            return pkg.schemaToken + ".xsd"
        else
            return pkg.bundle.replace('.', '/') + "/" + pkg.schemaToken + ".xsd"
    }


    /**
     * xsd generation entry point. The strategy is to loop over all packages and create one xsd per package,
     * with automatically derived short and long namespace IDs.
     *
     * Assumption is that no package is contained in two separate bon files.
     */
    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext unused) {
        val prefs = BonScriptPreferences.currentPrefs
        GENERATE_XSD_BY_DEFAULT     = prefs.xsdDefault
        ROOT_ELEMENTS_SEPARATE      = prefs.xsdRootSeparateFile
        SUBFOLDERS_FOR_BUNDLES      = prefs.xsdBundleSubfolders
        GENERATE_EXTENSION_FIELDS   = prefs.xsdExtensions

        // package check commented out. For one file, it's already done by the NamesAreUnique fragment,
        // across files, multiple invocations of the XsdBonScriptGeneratorMain are done
        // and doing it using a static set could cause issues when creation is invoked multiple times in interactive (Eclipse UI) mode.
//        val uniquePackageCheck = new HashSet<String>()

        for (pkg : resource.allContents.toIterable.filter(typeof(PackageDefinition))) {
            if (pkg.xmlAccess?.x !== XXmlAccess.NONE && (GENERATE_XSD_BY_DEFAULT || pkg.xmlAccess !== null)) {
//                if (!uniquePackageCheck.add(pkg.name))
//                    throw new Exception('''Project contains multiple packages of name «pkg.name», XSD prefix clash''')
                fsa.generateTracedFile(GENERATED_XSD_SUBFOLDER + "lib/" + pkg.computeXsdFilename, pkg, xRef[pkg.writeXsdFile])

                // also generate entry points for all the root elements
                if (ROOT_ELEMENTS_SEPARATE) {
                    for (cls: pkg.classes) {
                        if (cls.isXmlRoot)
                            fsa.generateTracedFile(GENERATED_XSD_SUBFOLDER + cls.name + ".xsd", cls, xRef[cls.writeXsdFile])
                    }
                }
            }
        }
    }


    def private boolean notYetVisited(EObject e) {
        return visitedMarker.add(e)
    }

    def private void addConditionally(EObject e) {
        val pkg = e?.package
        if (pkg !== null)
            requiredImports.add(pkg)
    }

    def private void collectClassRefImports(ClassReference r) {
        if (r !== null && r.notYetVisited) {
            r.classRef.addConditionally
            val rr = r.genericsParameterRef?.extends
            if (r != rr)        // avoid endless recursion for meta.AbstractObjectParent
                rr?.collectClassRefImports
            for (arg: r.classRefGenericParms)
                arg.collectClassRefImports
        }
    }

    def private void collectDataTypeImports(DataType dt) {
        if (dt.notYetVisited) {
            if (dt.elementaryDataType !== null) {
                val e = dt.elementaryDataType
                e.enumType.addConditionally
                e.xenumType.addConditionally
                e.enumsetType.addConditionally
                e.xenumsetType.addConditionally
            } else if (dt.referenceDataType !== null) {
                val r = dt.referenceDataType
                if (r.datatype !== null) {
                    r.datatype.addConditionally
                    r.datatype.collectDataTypeImports
                }
            } else {
                dt.objectDataType?.classRef.addConditionally
            }
        }
    }

    def private collectXmlImports(PackageDefinition pkg) {
        for (td : pkg.types)
            td.datatype?.collectDataTypeImports

        for (cls : pkg.classes) {
            // process the class, unless visited before (should not happen at this point)
            if (cls.notYetVisited) {
                // import the parent class, if it exists
                cls.extendsClass.collectClassRefImports
                for (f: cls.fields)
                    f.datatype.collectDataTypeImports
                // import any generic parameters references
                for (p: cls.genericParameters)
                    p.extends.collectClassRefImports
            }
        }
    }

    // distinction between numeric / alphanumeric enum types. Not used, as JAXB always uses the name, and neither the ordinal nor the token
    def public createMbEnumTypes(PackageDefinition pkg) {
        return '''
            «FOR en: pkg.enums»
                <xs:simpleType name="«en.name»">
                    «IF en.isAlphaEnum»
                        <xs:restriction base="xs:string">
                            «FOR v: en.avalues»
                                <xs:enumeration value="«v.token»"/>
                            «ENDFOR»
                        </xs:restriction>
                    «ELSE»
                        <xs:restriction base="xs:integer">
                            <xs:minInclusive value="0"/>
                            <xs:maxInclusive value="«en.values.size - 1»"/>
                        </xs:restriction>
                    «ENDIF»
                </xs:simpleType>
            «ENDFOR»
        '''
    }

	@Traced
    def public createEnumType(EnumDefinition en) {
        return '''
            <xs:simpleType name="«en.name»">
                <xs:restriction base="xs:string">
                    «IF en.isAlphaEnum»
                        «FOR v: en.avalues»
                            <xs:enumeration value="«v.name»"/>
                        «ENDFOR»
                    «ELSE»
                        «FOR v: en.values»
                            <xs:enumeration value="«v»"/>
                        «ENDFOR»
                    «ENDIF»
                </xs:restriction>
            </xs:simpleType>
        '''
    }

	@Traced
    def public createXEnumType(XEnumDefinition en) {
        return '''
            <xs:simpleType name="«en.name»">
                <xs:restriction base="xs:string">
                    <xs:maxLength value="«en.root.overallMaxLength»"/>
                </xs:restriction>
            </xs:simpleType>
        '''
    }

	@Traced
    def public createEnumsetType(EnumSetDefinition en) {
        return '''
            <xs:simpleType name="«en.name»">
                <xs:list itemType="«en.myEnum.name.xsdQualifiedName(en.myEnum.package)»"/>
            </xs:simpleType>
        '''
    }

	@Traced
    def public createXEnumsetType(XEnumSetDefinition en) {
        return '''
            <xs:simpleType name="«en.name»">
                <xs:list itemType="«en.myXEnum.name.xsdQualifiedName(en.myXEnum.package)»"/>
            </xs:simpleType>
        '''
    }

    def public createTypeDefs(PackageDefinition pkg) {
        return '''
            «FOR td: pkg.types»
                <xs:simpleType name="«td.name»"«describeField(pkg, td.datatype, null)»
            «ENDFOR»
        '''
    }

    // specify the max occurs clause
    def public howManyMax(int limit) {
        if (limit <= 0)
            return ''' maxOccurs="unbounded"'''
        else if (limit != 1)
            return ''' maxOccurs="«limit»"'''
    }

    // specify the min occurs clause
    def public howManyMin(int limit) {
        if (limit != 1)
            return ''' minOccurs="«limit»"'''
    }

    // nillable = true allows to send empty tags for nulls, minOccurs allows omitting the tag
    def public obtainOccurs(FieldDefinition f) {
        // for aggregates
        val nillable = if (!f.isRequired) ' nillable="true"'  // for aggregates (List) nillable is important to indicate blank entries
        if (f.isArray !== null)
            return '''«f.isArray.mincount.howManyMin»«f.isArray.maxcount.howManyMax»«nillable»'''
        else if (f.isList !== null)
            return '''«f.isList.mincount.howManyMin»«f.isList.maxcount.howManyMax»«nillable»'''
        else if (f.isSet !== null)
            return '''«f.isSet.mincount.howManyMin»«f.isSet.maxcount.howManyMax»«nillable»'''
        else if (f.isMap !== null)
            return '''«f.isMap.mincount.howManyMin»«f.isMap.maxcount.howManyMax»«nillable»'''
        else {
            // scalar field: if json or array, set maxOccurs to unbounded
            val ref = DataTypeExtension.get(f.datatype)
            val typename = ref.elementaryDataType?.name?.toLowerCase

//            if (typename == "json")
//                return ''' minOccurs="0" maxOccurs="unbounded"'''
            if (typename == "array")
                return ''' minOccurs="0" maxOccurs="unbounded" nillable="true"'''
            if (!f.isRequired)
                return ''' minOccurs="0" nillable="true"'''
        }
    }

    def wrap(CharSequence content, String terminator) {
        if (terminator !== null) {
            // inside element: must open a new simpleType element
            return '''
                >
                    <xs:simpleType>
                        «content»
                    </xs:simpleType>
                </«terminator»>
            '''
        } else {
            return '''
                >
                    «content»
                </xs:simpleType>
            '''
        }
    }

    def typeWrap(CharSequence content, String terminator) {
        if (terminator !== null) {
            return ''' type="«content»"/>'''
        } else {
            // not inside element: in simpleType, must use an artifical restiction (with no restrictions)
            return '''
                >
                    <xs:restriction base="«content»"/>
                </xs:simpleType>
            '''
        }
    }

    def public defIntegral(ElementaryDataType e, boolean signed, String name, String unsignedLimit, String terminator) {
        val finalName = '''xs:«IF signed»«name»«ELSE»unsigned«name.toFirstUpper»«ENDIF»'''
        var String minLimit = null
        var String maxLimit = null
        if (e.length <= 0) {
            // unbounded type: specify min/max if unsigned, as Java has no unsigned numbers
            if (signed)
                return finalName.typeWrap(terminator)
            else
                maxLimit = '''<xs:maxInclusive value="«unsignedLimit»"/>'''
        } else {
            // define upper and lower symmetric limits
            val limit = Strings.repeat("9", e.length)

            if (signed) {
                minLimit = '''<xs:minInclusive value="-«limit»"/>'''
            }

            maxLimit = '''<xs:maxInclusive value="«limit»"/>'''
        }
        return '''
            <xs:restriction base="«finalName»">
                «minLimit»
                «maxLimit»
            </xs:restriction>
        '''.wrap(terminator)
    }

    def public defString(ElementaryDataType e, boolean trim, String pattern, String terminator) {
        return '''
            <xs:restriction base="xs:«IF trim»normalizedString«ELSE»string«ENDIF»">
                «IF e.minLength > 0»<xs:minLength value="«e.minLength»"/>«ENDIF»
                <xs:maxLength value="«e.length»"/>
                «IF pattern !== null»<xs:pattern value="«pattern»"/>«ENDIF»
            </xs:restriction>
        '''.wrap(terminator)
    }

    def private defBinary(ElementaryDataType e, String terminator) {
        if (e.length <= 0 || e.length == Integer.MAX_VALUE)
            return "xs:base64Binary".typeWrap(terminator)   // unbounded
        else
            return '''
                <xs:restriction base="xs:base64Binary">
                    <xs:maxLength value="«e.length»"/>
                </xs:restriction>
            '''.wrap(terminator)
    }

    // method is called with inElement = false for type defs and with inElement = true for fields of complex types
    def public CharSequence describeField(PackageDefinition pkg, DataType dt, String terminator) {
        if (dt.referenceDataType !== null) {
            val typeDef = dt.referenceDataType
            return typeDef.name.xsdQualifiedName(typeDef.package).typeWrap(terminator)
        }
        // no type definition, embedded tpe is used
        val ref = dt.rootDataType
        if (ref.elementaryDataType !== null) {
            val e = ref.elementaryDataType
            switch (e.name.toLowerCase) {
                case 'float':       return "xs:float".typeWrap(terminator)
                case 'double':      return "xs:double".typeWrap(terminator)
                case 'decimal':
                    return '''
                        <xs:restriction base="xs:decimal">
                            <xs:totalDigits value="«e.length»"/>
                            <xs:fractionDigits value="«e.decimals»"/>
                            «IF !ref.effectiveSigned» <xs:minInclusive value="0"/>«ENDIF»
                        </xs:restriction>
                    '''.wrap(terminator)
                case 'number':
                    return '''
                        <xs:restriction base="xs:integer">
                            <xs:totalDigits value="«e.length»"/>
                            «IF !ref.effectiveSigned» <xs:minInclusive value="0"/>«ENDIF»
                        </xs:restriction>
                    '''.wrap(terminator)
                case 'integer':     return e.defIntegral(ref.effectiveSigned, "int",   Integer.MAX_VALUE.toString, terminator)
                case 'int':         return e.defIntegral(ref.effectiveSigned, "int",   Integer.MAX_VALUE.toString, terminator)
                case 'long':        return e.defIntegral(ref.effectiveSigned, "long",  Long.MAX_VALUE.toString, terminator)
                case 'byte':        return e.defIntegral(ref.effectiveSigned, "byte",  "127", terminator)
                case 'short':       return e.defIntegral(ref.effectiveSigned, "short", "32767", terminator)
                case 'unicode':     return e.defString(ref.effectiveTrim, null, terminator)
                case 'uppercase':   return e.defString(ref.effectiveTrim, "([A-Z])*", terminator)
                case 'lowercase':   return e.defString(ref.effectiveTrim, "([a-z])*", terminator)
                case 'ascii':       return e.defString(ref.effectiveTrim, "\\p{IsBasicLatin}*", terminator)
                case 'object':      return "bon:BONAPORTABLE"  /* "xs:anyType" */.typeWrap(terminator)
                // temporal types
                case 'day':         return "xs:date"    .typeWrap(terminator)
                case 'time':        return "xs:time"    .typeWrap(terminator)
                case 'timestamp':   return "xs:dateTime".typeWrap(terminator)
                case 'instant':     return "xs:long"    .typeWrap(terminator)
                // misc
                case 'boolean':     return "xs:boolean" .typeWrap(terminator)
                case 'character':   return "bon:CHAR"   .typeWrap(terminator)
                case 'char':        return "bon:CHAR"   .typeWrap(terminator)
                case 'uuid':        return "bon:UUID"   .typeWrap(terminator)
                case 'raw':         return e.defBinary(terminator)
                case 'binary':      return e.defBinary(terminator)
                // enum stuff
                case 'enum':        return e.enumType    .name.xsdQualifiedName(e.enumType    .package).typeWrap(terminator)
                case 'xenum':       return e.xenumType   .name.xsdQualifiedName(e.xenumType   .package).typeWrap(terminator)
                case 'enumset':     return e.enumsetType .name.xsdQualifiedName(e.enumsetType .package).typeWrap(terminator)
                case 'xenumset':    return e.xenumsetType.name.xsdQualifiedName(e.xenumsetType.package).typeWrap(terminator)
                // JSON types
                case 'element':     return "xs:anyType".typeWrap(terminator)
                case 'array':       return "xs:anyType".typeWrap(terminator)    // same but force unlimited recurrence
                case 'json':        return "bon:JSON"  .typeWrap(terminator)    // key/value pair type
            }
        } else if (ref.objectDataType !== null) {
            // check for explicit reference (no subtypes)
            return ref.objectDataType.xsdQualifiedName(pkg).typeWrap(terminator)
        } else {
            // plain object (i.e. any bonaportable)
            return "bon:BONAPORTABLE".typeWrap(terminator)  /* "xs:anyType" */
        }
    }

    def public listAttributes(ClassDefinition cls, PackageDefinition pkg) {
        val xmlUpper = cls.isXmlUpper
        return '''
            «FOR f: cls.fields.filter[properties.hasProperty(PROP_ATTRIBUTE)]»
                <xs:attribute name="«xmlName(f, xmlUpper)»"«IF f.isRequired» use="required"«ENDIF»«describeField(pkg, f.datatype, "xs:attribute")»
            «ENDFOR»
        '''
    }

    def public listDeclaredFields(ClassDefinition cls, PackageDefinition pkg) {
        val xmlUpper = cls.isXmlUpper
        return '''
            <xs:sequence>
                «FOR f: cls.fields.filter[!properties.hasProperty(PROP_ATTRIBUTE)]»
                    <xs:element name="«xmlName(f, xmlUpper)»"«f.obtainOccurs»«describeField(pkg, f.datatype, "xs:element")»
                «ENDFOR»
                «IF GENERATE_EXTENSION_FIELDS && cls.final»
                    <!-- allow for upwards compatible type extensions -->
                    <xs:element name="extensions«cls.name»" type="xs:anyType" minOccurs="0" maxOccurs="unbounded" nillable="true"/>
                «ENDIF»
            </xs:sequence>
        '''
    }

    /** Inserts code to refer to a substitution group. */
    def public printSubstGroup(ClassDefinition cls) {
//        if (cls.extendsClass?.classRef !== null) {
//            return ''' substitutionGroup="«cls.extendsClass?.classRef.xsdQualifiedName(cls.package)»"'''
//        } else {
//            return ''' substitutionGroup="bon:BONAPORTABLE"'''
//        }
        return null
    }

    /** Creates all complexType definitions for the package. */
    def public createObjects(PackageDefinition pkg) {
//        return '''
//            «FOR cls: pkg.classes»
//                <xs:complexType name="«cls.name»"«IF cls.abstract» abstract="true"«ENDIF»«if (cls.final) ' block="#all" final="#all"'»«cls.printSubstGroup»>
//                    «IF cls.extendsClass?.classRef !== null»
//                        <xs:complexContent>
//                            <xs:extension base="«cls.extendsClass?.classRef.xsdQualifiedName(pkg)»">
//                                «cls.listDeclaredFields(pkg)»
//                            </xs:extension>
//                        </xs:complexContent>
//                    «ELSE»
//                        «cls.listDeclaredFields(pkg)»
//                    «ENDIF»
//                </xs:complexType>
//            «ENDFOR»
//        '''
        return '''
            «FOR cls: pkg.classes»
                <xs:complexType name="«cls.name»"«IF cls.abstract» abstract="true"«ENDIF»«if (cls.final) ' block="#all" final="#all"'»«cls.printSubstGroup»>
                    «cls.listAttributes(pkg)»
                    <xs:complexContent>
                        <xs:extension base="«cls.extendsClass?.classRef?.xsdQualifiedName(pkg) ?: "bon:BONAPORTABLE"»">
                            «cls.listDeclaredFields(pkg)»
                        </xs:extension>
                    </xs:complexContent>
                </xs:complexType>
            «ENDFOR»
        '''
    }

    def private topLevelElement(ClassDefinition cls, PackageDefinition pkg) {
        return '''
            «IF cls.xmlListName !== null»
                <xs:element name="«cls.xmlListName»">
                    <xs:complexType>
                        <xs:sequence>
                            <xs:element name="«cls.name»" type="«pkg.schemaToken»:«cls.name»"«cls.minXmlcount.howManyMin»«cls.maxXmlcount.howManyMax»/>
                        </xs:sequence>
                    </xs:complexType>
                </xs:element>
            «ELSE»
                <xs:element name="«cls.name»" type="«pkg.schemaToken»:«cls.name»"/>
            «ENDIF»
        '''
    }

    def private createTopLevelElements(PackageDefinition pkg) {
        return '''
            «FOR cls: pkg.classes»
                «IF cls.isIsXmlRoot»
                    «cls.topLevelElement(pkg)»
                «ENDIF»
            «ENDFOR»
        '''
    }

    def public xsdQualifiedName(String name, PackageDefinition referencedPkg) {
//        if (myPkg === referencedPkg)
//            return name
//        else
            return '''«referencedPkg.schemaToken»:«name»'''
    }

    /** Prints a qualified name with an optional namespace prefix. */
    def public xsdQualifiedName(ClassDefinition cls, PackageDefinition ref) {
        return '''«cls.package.schemaToken»:«cls.name»'''
    }

    def private boolean inSameBundle(PackageDefinition p1, PackageDefinition p2) {
        if (p1.bundle === null)
            return p2.bundle === null
        else
            return p1.bundle == p2.bundle
    }

    def private static writeFormDefaults(PackageDefinition d) {
        // use different defaults for elements and attributes for backwards compatibility
        val xmlElementFormDefault = d.xmlElementFormDefault?.x     ?: XXmlFormDefault.QUALIFIED
        val xmlAttributeFormDefault = d.xmlAttributeFormDefault?.x ?: XXmlFormDefault.UNSET
        return '''
            «IF xmlElementFormDefault != XXmlFormDefault.UNSET»elementFormDefault="«xmlElementFormDefault.toString.toLowerCase»"«ENDIF»
            «IF xmlAttributeFormDefault != XXmlFormDefault.UNSET»attributeFormDefault="«xmlAttributeFormDefault.toString.toLowerCase»"«ENDIF»
        '''
    }

    /** Top level entry point to create the XSD file for a whole package. */
    def private writeXsdFile(PackageDefinition pkg) {
        val prefix = pkg.computeRelativePathPrefix
        requiredImports.clear       // clear hash for this new package output
        visitedMarker.clear         // clear marker for visited objects (speedup, but primarily to avoid endless recursion)
        pkg.collectXmlImports
        requiredImports.remove(pkg) // no include for myself

        val sortedImports = requiredImports.sortBy[schemaToken]     // need a reliable ordering, because XSDs generation should provide predictable results

        return '''
            <?xml version="1.0" encoding="UTF-8"?>
            «GENERATED_COMMENT»
            <xs:schema targetNamespace="«pkg.effectiveXmlNs»"
              xmlns:xs="http://www.w3.org/2001/XMLSchema"
              xmlns:bon="http://www.jpaw.de/schema/bonaparte.xsd"
              xmlns:«pkg.schemaToken»="«pkg.effectiveXmlNs»"
              «FOR imp: sortedImports»
                xmlns:«imp.schemaToken»="«imp.effectiveXmlNs»"
              «ENDFOR»
              «pkg.writeFormDefaults»>

                <xs:import namespace="http://www.jpaw.de/schema/bonaparte.xsd" schemaLocation="«prefix»bonaparte.xsd"/>
                «FOR imp: sortedImports»
                    <xs:import namespace="«imp.effectiveXmlNs»" schemaLocation="«IF inSameBundle(pkg, imp)»«imp.schemaToken».xsd«ELSE»«prefix»«imp.computeXsdFilename»«ENDIF»"/>
                «ENDFOR»
                «IF !ROOT_ELEMENTS_SEPARATE»
                    «pkg.createTopLevelElements»
                «ENDIF»
    	        «FOR en1: pkg.enums»
                    «en1.createEnumType»
                «ENDFOR»
	            «FOR en2: pkg.xenums»
                    «en2.createXEnumType»
                «ENDFOR»
                «FOR en3: pkg.enumSets»
                «en3.createEnumsetType»
                «ENDFOR»
                «FOR en4: pkg.xenumSets»
                    «en4.createXEnumsetType»
                «ENDFOR»
                «pkg.createTypeDefs»
                «pkg.createObjects»
            </xs:schema>
        '''
    }

    /** Top level entry point to create the XSD file for a root element. */
    def private writeXsdFile(ClassDefinition cls) {
        val pkg = cls.package
        return '''
            <?xml version="1.0" encoding="UTF-8"?>
            «GENERATED_COMMENT»
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="«pkg.effectiveXmlNs»"
              xmlns:«pkg.schemaToken»="«pkg.effectiveXmlNs»"
              «cls.package.writeFormDefaults»>

                <xs:include schemaLocation="lib/«pkg.computeXsdFilename»"/>

                «cls.topLevelElement(pkg)»
            </xs:schema>
        '''
    }
}
