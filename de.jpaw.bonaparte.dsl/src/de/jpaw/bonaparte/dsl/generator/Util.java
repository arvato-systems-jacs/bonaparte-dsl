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

import java.util.ArrayList;
import java.util.List;

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition;
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition;

public class Util {
	static public boolean useJoda() {  // configuration: use JodaTime instead of Date/Gregorian?
		return true;
	}
	
	// return false if the string contains a non-ASCII printable character, else true
	public static boolean isAsciiString(String s) {
		if (s != null) {
			for (int i = 0; i < s.length(); ++i) {
				int c = (int)s.charAt(i);
				if (c < 0x20 || c > 0x7f)
					return false;
			}
		}
		return true;
	}
	
	static public String capInitial(String s) {
		return Character.toUpperCase(s.charAt(0)) + s.substring(1);
	}
/*
	static List<FieldDefinition> allElementaryDataElements(ClassDefinition dg) {
		List<FieldDefinition> r = new ArrayList<FieldDefinition>();
		for (FieldDefinition de : dg.getFields()) {
			if (de.getDatatype() != null)
				r.add(de);
		}
		return r;
	}

	static List<FieldDefinition> allElementaryDataElementsOrNull(
			ClassDefinition dg) {
		List<FieldDefinition> r = allElementaryDataElements(dg);
		return r.isEmpty() ? null : r;
	}

	static List<FieldDefinition> allGroupElements(ClassDefinition dg) {
		List<FieldDefinition> r = new ArrayList<FieldDefinition>();
		for (FieldDefinition de : dg.getFields()) {
			if (de.getDatatype().getObjectDataType() != null)
				r.add(de);
		}
		return r;
	}

	static List<FieldDefinition> allGroupElementsOrNull(ClassDefinition dg) {
		List<FieldDefinition> r = allGroupElements(dg);
		return r.isEmpty() ? null : r;
	} */
}
