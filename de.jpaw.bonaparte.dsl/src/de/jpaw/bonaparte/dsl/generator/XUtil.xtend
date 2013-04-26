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
  
package de.jpaw.bonaparte.dsl.generator

import java.util.List

import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType
import de.jpaw.bonaparte.dsl.bonScript.DataType
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.bonScript.GenericsDef
import de.jpaw.bonaparte.dsl.bonScript.XRequired
import de.jpaw.bonaparte.dsl.bonScript.ClassReference
// using JCL here, because it is already a project dependency, should switch to slf4j
import org.apache.commons.logging.Log
import org.apache.commons.logging.LogFactory
import de.jpaw.bonaparte.dsl.bonScript.MapModifier

class XUtil {
    private static Log logger = LogFactory::getLog("de.jpaw.bonaparte.dsl.generator.XUtil") // jcl
    
    def public static ClassDefinition getParent(ClassDefinition d) {
        if (d == null || d.getExtendsClass == null)
            return null;
        d.getExtendsClass.getClassRef
    }

    def public static ClassDefinition getRoot(ClassDefinition d) {
        var dd = d
        while (getParent(dd) != null)
            dd = getParent(dd)
        return dd
    }
    
    def public static boolean isImmutable(ClassDefinition d) {
        return getRoot(d).immutable
    }
    
    def public static String genericRef2String(ClassReference r) {
        if (r.plainObject)
            return "BonaPortable"
        if (r.genericsParameterRef != null)
            return r.genericsParameterRef.name
        if (r.classRef != null)
            return r.classRef.name + genericArgs2String(r.classRefGenericParms)
            
        logger.error("*** FIXME: class reference with all null fields ***")
        return "*** FIXME: class reference with all null fields ***"        
    }
    
    def public static genericArgs2String(List<ClassReference> args) {
        if (args == null)
            return ""
        '''«FOR a : args BEFORE '<' SEPARATOR ', ' AFTER '>'»«genericRef2String(a)»«ENDFOR»'''        
    }
    
    def public static genericDef2String(List<GenericsDef> args) {
        if (args == null)
            return ""
        '''«FOR a : args BEFORE '<' SEPARATOR ', ' AFTER '>'»«a.name»«IF a.^extends != null» extends «genericRef2String(a.^extends)»«ENDIF»«ENDFOR»'''        
    }
    
    def public static genericDef2StringAsParams(List<GenericsDef> args) {
        if (args == null)
            return ""
        '''«FOR a : args BEFORE '<' SEPARATOR ', ' AFTER '>'»«a.name»«ENDFOR»'''        
    }
    
    // get the elementary data object after resolving typedefs
    // uses caching to keep overall running time at O(1) per call
    def public static ElementaryDataType resolveElem(DataType d) {
        DataTypeExtension::get(d).elementaryDataType
    }
    
    // get the class / object reference after resolving typedefs
    // uses caching to keep overall running time at O(1) per call
    def public static ClassDefinition resolveObj(DataType d) {
        DataTypeExtension::get(d).objectDataType
    }
    // Utility methods
    def public static getPartiallyQualifiedClassName(ClassDefinition d) {
        JavaPackages::getPackage(d).name + "." + d.name  
    }
    // create a serialVersionUID which depends on class name and revision, plus the same for any parent classes only
    def public static long getSerialUID(ClassDefinition d) {
        var long myUID = getPartiallyQualifiedClassName(d).hashCode()
        if (d.revision != null)
            myUID = 97L * myUID + d.revision.hashCode()
        if (d.extendsClass != null && d.extendsClass.classRef != null)
            myUID = 131L * myUID + getSerialUID(d.extendsClass.classRef)   // recurse parent classes
        return myUID
    }
    
    // convert an Xtend boolean to Java source token
    def public static b2A(boolean f) {
        if (f) "true" else "false"
    }
    
    // convert a String to Java source token, keeping nulls
    def public static s2A(String s) {
        if (s == null) return "null" else return '''"«Util::escapeString2Java(s)»"'''
    }
    
    def public static indexedName(FieldDefinition i) {
        if (i.isList != null) "_i" else if (i.isMap != null) "_i.getValue()" else i.name + (if (i.isArray != null) "[_i]" else "")
    }
    
    def public static int mapIndexID(MapModifier i) {
        if (i.indexType == "String")
            return 1
        if (i.indexType == "Integer")
            return 2
        if (i.indexType == "Long")
            return 3
        return 0  // should not happen
    }
    
    def public static loopStart(FieldDefinition i) '''
        «IF i.isArray != null»
            if («i.name» != null)
                for (int _i = 0; _i < «i.name».length; ++_i)
        «ELSEIF i.isList != null»
            if («i.name» != null)
                for («JavaDataTypeNoName(i, true)» _i : «i.name»)
        «ELSEIF i.isMap != null»
            if («i.name» != null)
                for (Map.Entry<«i.isMap.indexType»,«JavaDataTypeNoName(i, true)» _i : «i.name».entrySet())
        «ENDIF»
        '''
        
    def public static String getJavaDataType(DataType d) {
        val ref = DataTypeExtension::get(d)
        if (ref.isPrimitive)
            ref.elementaryDataType.name
        else
            ref.javaType
    }
    // the same, more complex scenario
    def public static JavaDataTypeNoName(FieldDefinition i, boolean skipIndex) {
        var String dataClass
        //fieldDebug(i)
        if (resolveElem(i.datatype) != null)
            dataClass = getJavaDataType(i.datatype)
        else {
            dataClass = DataTypeExtension::get(i.datatype).javaType
        }
        if (skipIndex)
            dataClass
        else if (i.isArray != null)
            dataClass + "[]" 
        else if (i.isList != null)
            "List<" + dataClass + ">" 
        else if (i.isMap != null)
            "Map<" + i.isMap.indexType + "," + dataClass + ">" 
        else
            dataClass
    }
    
    def public static boolean isRequired(FieldDefinition i) {
        var ref = DataTypeExtension::get(i.datatype)
        if (ref.isRequired != null) {
            if (i.required != null && i.required.x != null) {
                // both are defined. Check for consistency
                if (ref.isRequired != i.required.x) {
                    // late plausi check:
                    logger.error("requiredness of field " + i.name + " in class " + (i.eContainer as ClassDefinition).name
                        + " relabeled from " + ref.isRequired + " to " + i.required.x
                        + ". This is inconsistent.")
                }
            }
            return ref.isRequired == XRequired::REQUIRED
        }
        // now check if an explicit specification has been made
		if (i.required != null)
            return i.required.x	== XRequired::REQUIRED
			
        // neither ref.isRequired is set nor an explicit specification made.  Fall back to defaults of the embedding class or package
		
        // DEBUG
        //if (i.name.equals("fields"))
        //    System::out.println("fields.required = " + i.required + ", defaultreq = " + ref.defaultRequired)
        // if we have an object, it is nullable by default, unless some explicit or
        if (ref.defaultRequired != null)
            return ref.defaultRequired == XRequired::REQUIRED
        else
            return false  // no specification at all means optional
    }

    def public static condText(boolean flag, String text) {
        if (flag) text else "" 
    }
    
    def public static vlr(String text1, String l, String r, String otherwise) {
        if (text1 != null) l + text1 + r else otherwise
    }
    def public static nvl(String text1, String otherwise) {
        if (text1 != null) text1 else otherwise
    }
    def public static nnvl(String text1, String text2, String otherwise) {
        if (text1 != null) text1 else if (text2 != null) text2 else otherwise
    }
}