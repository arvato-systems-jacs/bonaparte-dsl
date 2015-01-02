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

import org.apache.commons.lang.StringEscapeUtils;

public class Util {
    static public String escapeString2Java(String s) {
        return StringEscapeUtils.escapeJava(s);
    }

    // return false if the string contains a non-ASCII printable character, else true
    public static boolean isAsciiString(String s) {
        if (s != null) {
            for (int i = 0; i < s.length(); ++i) {
                int c = s.charAt(i);
                if (c < 0x20 || c > 0x7e)
                    return false;
            }
        }
        return true;
    }

}
