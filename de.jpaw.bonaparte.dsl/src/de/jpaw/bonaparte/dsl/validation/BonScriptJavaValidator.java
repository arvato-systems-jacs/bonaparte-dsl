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

package de.jpaw.bonaparte.dsl.validation;

import org.eclipse.xtext.validation.Check;

import de.jpaw.bonaparte.dsl.bonScript.BonScriptPackage;
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition;
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType;
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition;
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition;
import de.jpaw.bonaparte.dsl.bonScript.XRequired;

public class BonScriptJavaValidator extends AbstractBonScriptJavaValidator {
	static private final int GIGABYTE = 1024 * 1024 * 1024;

	/* Despite all settings done for Java 1.7, project build complains about:
	 * An internal error occurred during: "Building workspace".
	 * Unresolved compilation problem: 
	 * Cannot switch on a value of type String for source level below 1.7.
	 * Only convertible int values or enum variables are permitted
	 * 
	 * So killing this plausi until the world decides to accept Java 7 
	
	@Check
	public void checkElementaryDataTypeLength(ElementaryDataType dt) {
		if (dt.getName() != null) {
			switch (dt.getName().toLowerCase()) {
			case "boolean":
			case "float":
			case "double":
			case "day":
			case "int":
			case "integer":
			case "long":
				return;
			case "timestamp": // similar to default, but allow 0 decimals and
								// max. 3 digits precision
				if (dt.getLength() < 0 || dt.getLength() > 3)
					error("Fractional seconds must be at least 0 and at most 3 digits",
							BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
				return;
			case "number":
				if (dt.getLength() <= 0 || dt.getLength() > 9)
					error("Mantissa must be at least 1 and at max 9",
							BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
				return;
			case "decimal":
				if (dt.getLength() <= 0 || dt.getLength() > 18)
					error("Mantissa must be at least 1 and at max 18",
							BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
				if (dt.getDecimals() < 0 || dt.getDecimals() > dt.getLength())
					error("Decimals may not be negative and must be at max length of mantissa",
							BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__DECIMALS);
				return;
			default:
				if (dt.getLength() <= 0 || dt.getLength() > GIGABYTE)
					error("Field size must be at least 1 and at most 1 GB",
							BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
			}
		}
	}
*/
	@Check
	public void checkClassDefinition(ClassDefinition cd) {
		String s = cd.getName();
		if (s != null) {
			if (!Character.isUpperCase(s.charAt(0)))
				error("Class names should start with an upper case letter",
						BonScriptPackage.Literals.CLASS_DEFINITION__NAME);
		}
		if (cd.getExtendsClass() != null) {
			// the extended class may not be final
			if (cd.getExtendsClass().isFinal())
				error("Classes max not extend a final class",
						BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
		}
	}
	
	// helper function for checkFieldDefinition
	private int countSameName(ClassDefinition cl,  String name) {
		int count = 0;
		for (FieldDefinition field: cl.getFields()) {
			if (name.equals(field.getName()))
				++count;
		}
		return count;
	}
	
	@Check
	public void checkFieldDefinition(FieldDefinition fd) {
		String s = fd.getName();
		if (s != null) {
			if (!Character.isLowerCase(s.charAt(0)))
				error("field names should start with a lower case letter",
						BonScriptPackage.Literals.FIELD_DEFINITION__NAME);
		}
		
		// check for unique name within this class and possible subclasses
		ClassDefinition cl = (ClassDefinition)fd.eContainer();  // Grammar dependency! FieldDefinition is only called from ClassDefinition right now 
		if (countSameName(cl, s) != 1)
			error("field name is not unique within this class",
					BonScriptPackage.Literals.FIELD_DEFINITION__NAME);
		// check parent classes as well
		for (ClassDefinition parentClass = cl.getExtendsClass(); parentClass != null; parentClass = parentClass.getExtendsClass())
			if (countSameName(parentClass, s) != 0)
				error("field occurs in extended class "
						+ ((PackageDefinition)parentClass.eContainer()).getName() + "."
						+ parentClass.getName() + " already (shadowing not allowed in bonaparte)",
						BonScriptPackage.Literals.FIELD_DEFINITION__NAME);
		
		if (fd.getRequired() != null) {
			// System.out.println("Checking " + s + ": getRequired() = <" + fd.getRequired().toString() + ">");
			// not allowed for typedefs right now
			if (fd.getDatatype() != null && fd.getDatatype().getReferenceDataType() != null) {
				error("required / optional attributes not allowed for type definitions: found <" + fd.getRequired().getX().toString() + "> for " + s,
						BonScriptPackage.Literals.FIELD_DEFINITION__REQUIRED);
			}
			if (fd.getRequired().getX() == XRequired.OPTIONAL && fd.getDatatype() != null) {
				ElementaryDataType dt = fd.getDatatype().getElementaryDataType();
				if (dt != null && dt.getName() != null && Character.isLowerCase(dt.getName().charAt(0)))
					error("optional attribute conflicts implicit 'required' meaning of lower case data type",
						BonScriptPackage.Literals.FIELD_DEFINITION__REQUIRED);
			}
		}
	}
}
