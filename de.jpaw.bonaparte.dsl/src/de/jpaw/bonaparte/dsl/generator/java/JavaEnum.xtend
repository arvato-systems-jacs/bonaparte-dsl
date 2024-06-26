 /*
  * Copyright 2012,2013 Michael Bischoff
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

import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import de.jpaw.bonaparte.dsl.BonScriptPreferences

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*

class JavaEnum {
    val static final int codegenJavaVersion = Integer.valueOf(System.getProperty("bonaparte.java.version", "8"))

    def static public boolean hasNullToken(EnumDefinition ed) {
        ed.avalues !== null && ed.avalues.exists[token == ""]
    }
    def static public nameForNullToken(EnumDefinition ed) {
        if (ed.avalues !== null)
            return ed.avalues.findFirst[token.empty]?.name
    }
    def static public boolean isAlphaEnum(EnumDefinition d) {
        d.avalues !== null && !d.avalues.empty
    }
    def static public writeEnumDefinition(EnumDefinition d, String timePackage) {
        val isAlphaEnum = d.isAlphaEnum
        val isSpecialAlpha = isAlphaEnum && d.avalues.exists[token == ""]
        val myInterface = if (isAlphaEnum) "BonaTokenizableEnum" else "BonaNonTokenizableEnum"
        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «getBonPackageName(d)»;

        import com.google.common.collect.ImmutableList;
        import «BonScriptPreferences.getDateTimePackage».Instant;

        import de.jpaw.bonaparte.pojos.meta.EnumDefinition;
        import de.jpaw.bonaparte.enums.«myInterface»;
        import de.jpaw.util.EnumIterator;
        import java.util.Iterator;

        «d.javadoc»
        «IF d.isDeprecated || (d.eContainer as PackageDefinition).isDeprecated»
            @Deprecated
        «ENDIF»
        public enum «d.name» implements «myInterface» {
            «IF !isAlphaEnum»
                «FOR v:d.values SEPARATOR ', '»«v»«ENDFOR»;
            «ELSE»
                «FOR v:d.avalues SEPARATOR ', '»«v.name»("«v.token»")«ENDFOR»;

                private final String _token;

                /** Constructs an enum by its token. */
                private «d.name»(String _token) {
                    this._token = _token;
                }

                /** Retrieves the token for a given instance. Never returns null. */
                @Override
                public String getToken() {
                    return _token;
                }

                /** static factory method«IF codegenJavaVersion >= 7» (requires Java 7)«ENDIF».
                  * Null is passed through, a non-null parameter will return a non-null response. */
                public static «d.name» factory(String _token) {
                    if (_token != null) {
                        «IF codegenJavaVersion >= 7»
                            switch (_token) {
                            «FOR v:d.avalues»
                                case "«v.token»": return «v.name»;
                            «ENDFOR»
                            default: throw new IllegalArgumentException("Enum «d.name» has no token " + _token + "!");
                            }
                        «ELSE»
                            «FOR v:d.avalues»
                                if (_token.equals("«v.token»")) return «v.name»;
                            «ENDFOR»
                            throw new IllegalArgumentException("Enum «d.name» has no token " + _token + "!");
                        «ENDIF»
                    }
                    return null;
                }

                // static method to return the instance with the null token, or null if no such exists
                public static «d.name» getNullToken() {
                    return «d.avalues.findFirst[token == ""]?.name ?: "null"»;
                }

                /** Same as factory(), but returns the special enum instance with a tokens of zero length (in case such a token exists) for null. */
                public static «d.name» factoryNWZ(String _token) {
                    return «IF isSpecialAlpha»_token == null ? «d.avalues.findFirst[token == ""].name» : «ENDIF»factory(_token);
                }

                /** Retrieves the token for a given instance. Returns null for the zero length token. */
                public static String getTokenNWZ(«d.name» _obj) {
                    return _obj == null«IF isSpecialAlpha» || _obj == «d.avalues.findFirst[token == ""].name»«ENDIF» ? null : _obj.getToken();
                }
            «ENDIF»

            private static final long serialVersionUID = «getSerialUID(d)»L;
            private static final «d.name»[] _ALL_VALUES = «d.name».values();  // it creates a new array (defensive copy) every time called, we do it once, OK to call here by JLS 8.9.2.2

            «d.writeEnumMetaData»

            /** Returns the enum instance which has the ordinal as specified by the parameter. Returns null for a null parameter.
              * valueOf by default only exists for String type parameters for enums. */
            public static «d.name» valueOf(Integer ordinal) {
                return ordinal == null ? null : valueOf(ordinal.intValue());
            }
            public static «d.name» valueOf(final int _ord) {
                if (_ord < 0 || _ord >= _ALL_VALUES.length)
                    throw new IllegalArgumentException("Enum «d.name» has no instance for ordinal " + Integer.toString(_ord));
                return _ALL_VALUES[_ord];
            }
            /** Returns an iterator which traverses all enum instances. */
            public static Iterator<«d.name»> iterator() {
                return new EnumIterator<«d.name»>(_ALL_VALUES);
            }

            «IF codegenJavaVersion >= 8»
                public static final Iterable<«d.name»> all = () -> new EnumIterator<«d.name»>(_ALL_VALUES); // constant in lower case to avoid name clash with possible enum instance name
            «ELSE»
                public static final Iterable<«d.name»> all = new Iterable<«d.name»>() { // constant in lower case to avoid name clash with possible enum instance name
                    @Override
                    public Iterator<«d.name»> iterator() {
                        return «d.name».iterator();
                    }
                };
            «ENDIF»
        }
        '''
    }

    def private static writeEnumMetaData(EnumDefinition d) {
        val isAlphaEnum = d.isAlphaEnum
        val myPackage = d.package
        return '''
            private static final String _PARTIALLY_QUALIFIED_CLASS_NAME = "«getPartiallyQualifiedClassName(d)»";
            private static final String _PARENT = null;
            private static final String _BUNDLE = «IF (myPackage.bundle !== null)»"«myPackage.bundle»"«ELSE»null«ENDIF»;
            public static final String my$PQON = _PARTIALLY_QUALIFIED_CLASS_NAME;

            private static final ImmutableList<String> _ids = new ImmutableList.Builder<String>()
                «IF !isAlphaEnum»
                    «FOR id: d.values»
                        .add("«id»")
                    «ENDFOR»
                «ELSE»
                    «FOR id: d.avalues»
                        .add("«id.name»")
                    «ENDFOR»
                «ENDIF»
               .build();
            «IF isAlphaEnum»
                private static final ImmutableList<String> _tokens = new ImmutableList.Builder<String>()
                    «FOR id: d.avalues»
                        .add("«id.token»")
                    «ENDFOR»
                    .build();
            «ENDIF»

            // extended meta data (for the enhanced interface)
            private static final EnumDefinition my$MetaData = new EnumDefinition(
                «d.name».class,
                false,
                true,
                _PARTIALLY_QUALIFIED_CLASS_NAME,
                _PARENT,
                _BUNDLE,
                Instant.now(),
                null,
                «JavaMeta.writeComments(d.javadoc, d.regularComment)»
                // now specific enum items
                «IF isAlphaEnum»
                    «JavaXEnum.getInternalMaxLength(d, 0)»,
                    «d.hasNullToken»,
                    _ids,
                    _tokens
                «ELSE»
                    -1,
                    false,
                    _ids,
                    null
                «ENDIF»
            );

            // get all the meta data in one go
            static public EnumDefinition enum$MetaData() {
                return my$MetaData;
            }

            «JavaMeta.writeCommonMetaData»
        '''
    }
}
