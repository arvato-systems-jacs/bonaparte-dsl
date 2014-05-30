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
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.InterfaceListDefinition
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.XBeanValidation
import de.jpaw.bonaparte.dsl.bonScript.XExternalizable
import de.jpaw.bonaparte.dsl.bonScript.XXmlAccess
import java.util.ArrayList
import java.util.HashMap
import java.util.List
import java.util.Map
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

import static extension de.jpaw.bonaparte.dsl.generator.Util.*
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.bonScript.XEnumDefinition
import de.jpaw.bonaparte.dsl.BonScriptPreferences
import de.jpaw.bonaparte.dsl.bonScript.XHazelcast

// generator for the language Java
class JavaBonScriptGeneratorMain implements IGenerator {

    var Map<String, String> requiredImports = new HashMap<String, String>()

    // create the filename to store a generated java class source in. Assumes subdirectory ./java
    def private static getJavaFilename(String pkg, String name) {
        return "java/" + pkg.replaceAll("\\.", "/") + "/" + name + ".java"
    }
    // create the filename to store the JAXB index in
    def private static getJaxbResourceFilename(String pkg) {
        return "resources/" + pkg.replaceAll("\\.", "/") + "/jaxb.index"
    }

    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        val needJoda = !BonScriptPreferences.currentPrefs.doDateTime
        requiredImports.clear()  // clear hash for this new class output
        for (d : resource.allContents.toIterable.filter(typeof(EnumDefinition)))
            fsa.generateFile(getJavaFilename(getPackageName(d), d.name), JavaEnum::writeEnumDefinition(d));
        for (d : resource.allContents.toIterable.filter(typeof(XEnumDefinition)))
            fsa.generateFile(getJavaFilename(getPackageName(d), d.name), JavaXEnum::writeXEnumDefinition(d));
        for (d : resource.allContents.toIterable.filter(typeof(ClassDefinition)).filter[!noJava])
            fsa.generateFile(getJavaFilename(getPackageName(d), d.name), d.writeClassDefinition);
        for (d : resource.allContents.toIterable.filter(typeof(PackageDefinition))) {
            // get a list of all classes which have an XML tag
            var List<ClassDefinition> classList = new ArrayList<ClassDefinition>()
            for (cl : d.classes)
                if (!cl.isAbstract && getRelevantXmlAccess(cl) != null)
                    classList.add(cl)
            if (classList.size() > 0)
                fsa.generateFile(getJaxbResourceFilename(getPackageName(d)), '''
                «FOR cl : classList»
                    «cl.name»
                «ENDFOR»
                ''')

            // also, write a package-info.java file, if javadoc on package level exists or if XML bindings are used
            if (d.javadoc != null || d.xmlAccess != XXmlAccess::NONE) {
                fsa.generateFile(getJavaFilename(getPackageName(d), "package-info"), '''
                    // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
                    // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
                    // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git

                    «IF d.xmlAccess != null»
                    @XmlJavaTypeAdapters({
                        «IF needJoda»
                            @XmlJavaTypeAdapter(type=LocalDate.class,       value=LocalDateAdapter.class),
                            @XmlJavaTypeAdapter(type=LocalTime.class,       value=LocalTimeAdapter.class),
                            @XmlJavaTypeAdapter(type=LocalDateTime.class,   value=LocalDateTimeAdapter.class),
                        «ENDIF»
                        @XmlJavaTypeAdapter(type=ByteArray.class,       value=ByteArrayAdapter.class)
                    })
                    «ENDIF»
                    «d.javadoc»
                    package «getPackageName(d)»;
                    «IF d.xmlAccess != null»

                        import javax.xml.bind.annotation.adapters.XmlJavaTypeAdapter;
                        import javax.xml.bind.annotation.adapters.XmlJavaTypeAdapters;
                        import de.jpaw.util.ByteArray;
                        import de.jpaw.xml.jaxb.ByteArrayAdapter;
                        «IF needJoda»
                            import org.joda.time.LocalDate;
                            import org.joda.time.LocalDateTime;
                            import org.joda.time.LocalTime;
                            import de.jpaw.xml.jaxb.LocalDateAdapter;
                            import de.jpaw.xml.jaxb.LocalTimeAdapter;
                            import de.jpaw.xml.jaxb.LocalDateTimeAdapter;
                        «ENDIF»
                    «ENDIF»
                ''')
            }
        }
        requiredImports.clear()  // cleanup, we don't know how long this object will live
    }


/* currently unused
            «JavaMethods::writeMethods(d)»
    def private recurseMethods(ClassDefinition d, boolean isRoot) {
        for (m : d.methods)
            if (m.returnObj != null)
                addImport(getPackageName(m.returnObj), m.returnObj.name)
        if (!isRoot || (isRoot && !d.isAbstract)) // if we are not root, descend all way through. Otherwise, descend if not abstract
            if (d.extendsClass != null)
                recurseMethods(d.extendsClass, false)
    }  */

    // decision classes for the package level settings
    def private static getExternalizable(ClassDefinition d) {
        val XExternalizable t = d.isExternalizable?.x ?: getPackage(d).isExternalizable?.x ?: BonScriptPreferences.getExternalizable
        return t != null && t != XExternalizable::NOEXT
    }
    // decision classes for the package level settings
    def private static getHazelSupport(ClassDefinition d) {
        return d.doHazelcast?.x ?: getPackage(d).doHazelcast?.x ?: BonScriptPreferences.getHazelSupport
    }
    def private static getBeanValidation(ClassDefinition d) {
        var XBeanValidation t = d.doBeanValidation?.x ?: getPackage(d).doBeanValidation?.x ?: XBeanValidation::NOBEAN_VAL  // default to creation of no bean validation annotations
        return t != null && t != XBeanValidation::NOBEAN_VAL
    }

    def private static interfaceOut(InterfaceListDefinition l) {
        '''«IF l != null»«FOR i : l.ilist», «i.qualifiedName»«ENDFOR»«ENDIF»'''
    }
    
    def private void checkOrderedByList(ClassDefinition d) {
        
    }
    
    def private static intComparable(ClassDefinition d) {
	    if (d.orderedByList != null)
	    	''', Comparable<«d.name»>'''
  	}
    def private static intHazel(XHazelcast doHazel) {
	    switch (doHazel) {
            case NOHAZEL:
            	null
            case DATA_SERIALIZABLE:
                ", DataSerializable"
            case IDENTIFIED_DATA_SERIALIZABLE:
                ", IdentifiedDataSerializable"
            case PORTABLE:
				", Portable"
            case BOTH:					// does not make sense? 
                ", Portable, IdentifiedDataSerializable"
        }
	}

    def writeClassDefinition(ClassDefinition d) {
    // map to evaluate if we have conflicting class names and need FQCNs
    // key is the class name, data is the package name
    // using FQONs in case of conflict is not yet implemented
        val String myPackageName = getPackageName(d)
        val ImportCollector imports = new ImportCollector(myPackageName)
        imports.recurseImports(d, true)
        imports.addImport(d)  // add myself as well
        if (d.returnsClassRef != null)
            imports.addImport(d.returnsClassRef)
        if (d.genericParameters != null)
            for (gp : d.genericParameters)
                if (gp.^extends != null)
                    imports.addImport(gp.^extends)
        // determine XML annotation support
        val XXmlAccess xmlAccess = getRelevantXmlAccess(d)
        val xmlNs = d.xmlNs
        val doExt = d.externalizable
        val doHazel = d.hazelSupport
        val doBeanVal = d.beanValidation
        if (d.orderedByList != null)
            d.checkOrderedByList()
    return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «getPackageName(d)»;
        
        «writeDefaultImports»
        «IF (xmlAccess != null && !d.isAbstract)»
            import javax.xml.bind.annotation.XmlAccessorType;
            import javax.xml.bind.annotation.XmlAccessType;
            import javax.xml.bind.annotation.XmlRootElement;
            import javax.xml.bind.annotation.XmlElement;
            import javax.xml.bind.annotation.XmlTransient;
            import javax.xml.bind.annotation.XmlAnyElement;
        «ENDIF»
        «JavaBeanValidation::writeImports(doBeanVal)»
        «IF doExt»
	        «JavaExternalize::writeExternalizeImports»
        «ENDIF»
        «IF doHazel != XHazelcast.NOHAZEL»
	        «JavaHazelSupport::writeHazelImports(doHazel)»
        «ENDIF»
        import com.google.common.collect.ImmutableList;
        import com.google.common.collect.ImmutableSet;
        import com.google.common.collect.ImmutableMap;
        «IF d.pkClass != null»
            import de.jpaw.bonaparte.annotation.RelatedKey;
        «ENDIF»
        import «bonaparteInterfacesPackage».BonaPortable;
        import «bonaparteInterfacesPackage».BonaPortableClass;
        import «bonaparteInterfacesPackage».MessageParser;
        import «bonaparteInterfacesPackage».MessageComposer;
        import «bonaparteInterfacesPackage».MessageParserException;
        import «bonaparteInterfacesPackage».ObjectValidationException;
        import «bonaparteInterfacesPackage».DataConverter;
        import «bonaparteInterfacesPackage».StaticMeta;
        import «bonaparteClassDefaultPackagePrefix».meta.*;
        «imports.createImports»


        «IF d.javadoc != null»
           «d.javadoc»
        «ENDIF»

        «IF (xmlAccess != null && !d.isAbstract)»
            @XmlRootElement«IF xmlNs != null»(namespace = "«xmlNs»")«ENDIF»
            @XmlAccessorType(XmlAccessType.«xmlAccess.toString»)
        «ENDIF»
        «IF d.pkClass != null»
            @RelatedKey(«JavaPackages::getPackageName(d.pkClass)».«d.pkClass.name».class)
        «ENDIF»
        @SuppressWarnings("all")
        «IF d.isDeprecated»
        @Deprecated
        «ENDIF»
        «d.properties.filter[key.annotationReference != null].map['''@«key.annotationReference.qualifiedName»«IF value != null»("«value.escapeString2Java»")«ENDIF»'''].join('\n')»    
        public«IF d.isFinal» final«ENDIF»«IF d.isAbstract» abstract«ENDIF» class «d.name»«genericDef2String(d.genericParameters)»«IF d.parent != null» extends «d.parent.name»«genericArgs2String(d.extendsClass.classRefGenericParms)»«ENDIF»
          implements BonaPortable«d.intComparable»«IF doExt», Externalizable«ENDIF»«intHazel(doHazel)»«interfaceOut(d.implementsInterfaceList)» {
            private static final long serialVersionUID = «getSerialUID(d)»L;

            «JavaMeta::writeMetaData(d)»
            «JavaFrozen::writeFreezingCode(d)»
            «JavaRtti::writeRtti(d)»
            «JavaFieldsGettersSetters::writeFields(d, doBeanVal)»
            «JavaFieldsGettersSetters::writeGettersSetters(d)»
            «JavaValidate::writePatterns(d)»
            «JavaSerialize::writeSerialize(d)»
            «JavaSerialize::writeFoldedSerialize(d)»
            «JavaDeserialize::writeDeserialize(d)»
            «JavaValidate::writeValidationCode(d)»
            «JavaCompare::writeHash(d)»
            «JavaCompare::writeComparisonCode(d)»
            «IF d.orderedByList != null»
                «JavaCompare::writeComparable(d)»
            «ENDIF»
            «IF doExt»
                «JavaExternalize::writeExternalize(d)»
            «ENDIF»
            «JavaHazelSupport::writeHazelIO(d, doHazel)»
            «JavaTreeWalker::writeTreeWalkerCode(d)»
            «JavaConstructor::writeConstructorCode(d)»

            @Override
            public String toString() {
                return ToStringHelper.toStringSL(this);
            }
        }
    '''
    }
    def JavaDeexternalize(ClassDefinition definition) { }

}
