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

package de.jpaw.bonaparte.dsl.generator;

// A class to extend the grammar's DataType EObject,
// in order to provide space for internal extra fields used by the code generator, but also
// in order to support O(1) lookup of recursive typedefs

import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import org.eclipse.emf.ecore.EObject;

import de.jpaw.bonaparte.dsl.bonScript.FieldDefaultsDefinition;
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition;
import de.jpaw.bonaparte.dsl.bonScript.TypeDefinition;
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition;
import de.jpaw.bonaparte.dsl.bonScript.DataType;
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType;
import de.jpaw.bonaparte.dsl.bonScript.XUsePrimitives;
import de.jpaw.bonaparte.dsl.bonScript.XVisibility;
import de.jpaw.bonaparte.dsl.bonScript.XRequired;
import de.jpaw.bonaparte.dsl.bonScript.XSignedness;
import de.jpaw.bonaparte.dsl.bonScript.XSpecialCharsSetting;
import de.jpaw.bonaparte.dsl.bonScript.XTrimming;

public class DataTypeExtension {
	// a lookup to determine if a data type can (should) be implemented as a Java primitive.
	// (LANGUAGE SPECIFIC: JAVA)
	private static final Set<String> JAVA_PRIMITIVES = new HashSet<String>(Arrays.asList(new String[] {
		"boolean", "int", "long", "float", "double", "byte", "short", "char"
	}));

	// a lookup to resolve typedefs. Also collects preprocessed information about a data type
	static private Map<DataType,DataTypeExtension> map = new HashMap<DataType,DataTypeExtension>(200);

	// a lookup to determine the Java data type to use for a given grammar type.
	// (LANGUAGE SPECIFIC: JAVA)
	static protected Map<String,String> dataTypeJava = new HashMap<String, String>(32);
	static {
		dataTypeJava.put("boolean",   "Boolean");
		dataTypeJava.put("int",       "Integer");
		dataTypeJava.put("integer",   "Integer");
		dataTypeJava.put("long",      "Long");
		dataTypeJava.put("float",     "Float");
		dataTypeJava.put("double",    "Double");
		dataTypeJava.put("number",    "Integer");
		dataTypeJava.put("decimal",   "BigDecimal");
		dataTypeJava.put("byte",      "Byte");
		dataTypeJava.put("short",     "Short");
		dataTypeJava.put("char",      "Character");
		
		dataTypeJava.put("raw",       "byte []");
		dataTypeJava.put("timestamp", "GregorianCalendar");  // temporary solution until JSR 310 has been implemented
		dataTypeJava.put("day",       "GregorianCalendar");  // temporary solution until JSR 310 has been implemented
		
		dataTypeJava.put("uppercase", "String");
		dataTypeJava.put("lowercase", "String");
		dataTypeJava.put("ascii",     "String");
		dataTypeJava.put("unicode",   "String");
		dataTypeJava.put("string",    "String");
		dataTypeJava.put("enum",      "@");  // artificial entry for enum
	}
	
	
	// member variables
	private boolean currentlyVisited = false;
	public ElementaryDataType elementaryDataType;
	public ClassDefinition objectDataType;
	public TypeDefinition typedef;
	public String javaType;  // resulting type after preprocessing, can be a java type or enum
	public boolean isUpperCaseOrLowerCaseSpecialType = false;  // true for uppercase or lowercase (has extra built-in validation function)
	// parameters which cascade down from global defaults to package defaults to class defaults (grammar: FieldDefaultsDefinition)
	public boolean effectiveSigned = true;
	public boolean effectiveTrim = false;
	public boolean effectiveAllowCtrls = false;
	public boolean isPrimitive = false;
	public boolean wasUpperCase = false;
	public XVisibility visibility;
	public XRequired defaultRequired;
	
	static public void clear() {
		map.clear();
	}
	
	static private void mergeFieldSpecsWithDefaults(DataTypeExtension r, DataType key) throws Exception {
		ElementaryDataType e = r.elementaryDataType;
		// find the parent which is the relevant package definition. These are 2 or 3 steps
		// (Package => Typedef => DataType key) or
		// (Package => ClassDefinition => FieldDefinition => DataType key)
		// Still, we keep this generic in order to support possible changes of the grammar
		PackageDefinition p = null;
		ClassDefinition cd = null;
		FieldDefaultsDefinition classdefs = null;
		
		for (EObject i = key.eContainer(); ; i = i.eContainer()) {
			if (i instanceof ClassDefinition) {
				cd = (ClassDefinition)i;
			} else if (i instanceof PackageDefinition) {
				p = (PackageDefinition)i;
				break;
			}
		}
		// assert results: p must exist, cd only if inside class
		if (p == null)
        	throw new Exception("no wrapping package found for " + e.getName());
		if (cd != null)
			classdefs = cd.getDefaults();

		// for every field, prefer field level setting (if exists here), then fall back to class defaults,
		// then to package defaults, and finally to hardcoded defaults
		r.visibility = classdefs != null && classdefs.getVisibility() != null
				        ? classdefs.getVisibility().getX()
				        : p.getDefaults() != null && p.getDefaults().getVisibility() != null
				            ? p.getDefaults().getVisibility().getX()
				            : XVisibility.DEFAULT;
				            
        XUsePrimitives up = classdefs != null && classdefs.getUsePrimitives() != null
							        ? classdefs.getUsePrimitives().getX()
							        : p.getDefaults() != null && p.getDefaults().getUsePrimitives() != null
							            ? p.getDefaults().getUsePrimitives().getX()
							            : XUsePrimitives.USE_PRIMITIVES;
        if (up == XUsePrimitives.USE_PRIMITIVES && JAVA_PRIMITIVES.contains(e.getName()))
        	r.isPrimitive = true;
        // TODO: else: map back types: char => Character, int => Integer
		
		XSignedness s = e.getSigned() != null
				        ? e.getSigned().getX()
				        : classdefs != null && classdefs.getSigned() != null
						        ? classdefs.getSigned().getX()
						        : p.getDefaults() != null && p.getDefaults().getSigned() != null
						            ? p.getDefaults().getSigned().getX()
						            : XSignedness.SIGNED;
		r.effectiveSigned = s == XSignedness.SIGNED;
		
		XTrimming t = e.getTrimming() != null
		        ? e.getTrimming().getX()
		        : classdefs != null && classdefs.getTrim() != null
				        ? classdefs.getTrim().getX()
				        : p.getDefaults() != null && p.getDefaults().getTrim() != null
				            ? p.getDefaults().getTrim().getX()
				            : XTrimming.NOTRIM;
        r.effectiveTrim = t == XTrimming.TRIM;

        XSpecialCharsSetting spc = e.getAllowCtrls() != null
		        ? e.getAllowCtrls().getX()
		        : classdefs != null && classdefs.getAllowCtrls() != null
				        ? classdefs.getAllowCtrls().getX()
				        : p.getDefaults() != null && p.getDefaults().getAllowCtrls() != null
				            ? p.getDefaults().getAllowCtrls().getX()
				            : XSpecialCharsSetting.ALLOW_CONTROL_CHARS;
        r.effectiveAllowCtrls = spc == XSpecialCharsSetting.ALLOW_CONTROL_CHARS;
        
        r.defaultRequired = classdefs != null && classdefs.getRequired() != null
        		             ? classdefs.getRequired().getX()
        		             : p.getDefaults() != null
        		                 ? p.getDefaults().getRequired().getX()
        		                 : null;
    }

	static public DataTypeExtension get(DataType key) throws Exception {
		// retrieve the DataTypeExtension class for the given key (auto-create it if not yet existing)
		DataTypeExtension r = map.get(key);
		if (r != null) {
			if (r.currentlyVisited)
				// can only occur for typedefs
				throw new Exception("recursive typedefs around " + r.typedef.getName());
			return r;
		}
		// does not exist, create a new one!
		r = new DataTypeExtension();
		r.elementaryDataType = key.getElementaryDataType();
		r.objectDataType = key.getObjectDataType();
		r.typedef = key.getReferenceDataType();
		if (r.elementaryDataType != null) {
			// immediate data: perform postprocessing. transfer defaults of embedding package to this instance
			ElementaryDataType e = r.elementaryDataType;

			// map extra (convenience) data types to their standard java names 
	        if (Character.isUpperCase(e.getName().charAt(0))) {
	            r.wasUpperCase = true;
	            if (e.getName().equals("Int"))
	            	e.setName("Integer");     // fix java naming inconsistency
	            if (e.getName().equals("Char"))
	            	e.setName("Character");   // fix java naming inconsistency
	        } else {
	            if (e.getName().equals("integer"))
	            	e.setName("int");         // fix java naming inconsistency
	            if (e.getName().equals("character"))
	            	e.setName("char");        // fix java naming inconsistency
	        }
	        r.javaType = dataTypeJava.get(e.getName().toLowerCase());
	        
			// merge the defaults specifications
			mergeFieldSpecsWithDefaults(r, key);
			
			// special handling for enums
	        if (r.javaType.equals("@"))  // special case for enum types: replace java type by referenced class
	        	r.javaType = e.getEnumType().getName();
	        else if (r.javaType == null)
	        	throw new Exception("unmapped Java data type for " + e.getName());
	        
	        // special treatment for uppercase / lowercase shorthands
	        if (r.javaType.equals("String"))
	            if (e.getName().equals("uppercase") || e.getName().equals("lowercase"))
	            	r.isUpperCaseOrLowerCaseSpecialType = true;
	        
	        //System.out.println("setting elem data type: " + e.getName() + String.format(": wasUpper=%b, primitive=%b, length=%d, key=",
	        //		r.wasUpperCase, r.isPrimitive, e.getLength()) + key);
		}
		// now resolve the typedef, if exists
		if (r.typedef != null) {
			r.currentlyVisited = true;
			// add to map
			map.put(key, r);
			DataTypeExtension resolvedReference = get(r.typedef.getDatatype());  // descend via DFS
			r.elementaryDataType = resolvedReference.elementaryDataType;
			r.objectDataType = resolvedReference.objectDataType;
			r.wasUpperCase = resolvedReference.wasUpperCase;
			r.isPrimitive = resolvedReference.isPrimitive;
        	r.effectiveSigned = resolvedReference.effectiveSigned;
        	r.effectiveTrim = resolvedReference.effectiveTrim;
        	r.effectiveAllowCtrls = resolvedReference.effectiveAllowCtrls;
        	r.javaType = resolvedReference.javaType;
        	r.visibility = resolvedReference.visibility;
        	r.defaultRequired = resolvedReference.defaultRequired;
        	r.isUpperCaseOrLowerCaseSpecialType = resolvedReference.isUpperCaseOrLowerCaseSpecialType;
			r.currentlyVisited = false;
		} else {
			// just simply store it (elementary data type or object reference)
			map.put(key, r);
		}
		return r;
	}
}
