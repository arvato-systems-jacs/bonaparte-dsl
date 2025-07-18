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

import de.jpaw.bonaparte.dsl.BonScriptPreferences
import de.jpaw.bonaparte.dsl.bonScript.ArrayModifier
import de.jpaw.bonaparte.dsl.bonScript.BonScriptPackage
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassReference
import de.jpaw.bonaparte.dsl.bonScript.ComparableFieldsList
import de.jpaw.bonaparte.dsl.bonScript.DataType
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType
import de.jpaw.bonaparte.dsl.bonScript.EnumAlphaValueDefinition
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.EnumSetDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.bonScript.GenericsDef
import de.jpaw.bonaparte.dsl.bonScript.InterfaceListDefinition
import de.jpaw.bonaparte.dsl.bonScript.ListModifier
import de.jpaw.bonaparte.dsl.bonScript.MapModifier
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.PropertyUse
import de.jpaw.bonaparte.dsl.bonScript.SetModifier
import de.jpaw.bonaparte.dsl.bonScript.XEnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.XRequired
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import org.eclipse.emf.common.util.EList
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.validation.Check

import static de.jpaw.bonaparte.dsl.generator.java.JavaXEnum.*

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*
import de.jpaw.bonaparte.dsl.bonScript.XEnumSetDefinition

class BonScriptValidator extends AbstractBonScriptValidator {
    static final int GIGABYTE = 1024 * 1024 * 1024;
    static public final int MAX_PQON_LENGTH = 255;     // keep in sync with length in bonaparte-java/StaticMeta
    static Map<String,Integer> maxDigitsIfLimited = new HashMap<String,Integer>(10) => [
        put("byte",    2)
        put("short",   4)
        put("int",     9)
        put("integer", 9)
        put("long",   18)
        put("decimal",18)
    ]
    /* Must change MANIFEST.MF to contain
     * Bundle-RequiredExecutionEnvironment: JavaSE-11
     * Otherwise, Eclipse will complain:
     * An internal error occurred during: "Building workspace".
     * Unresolved compilation problem:
     * Cannot switch on a value of type String for source level below 1.7.
     * Only convertible int values or enum variables are permitted
     *
     */

    @Check
    def void checkElementaryDataTypeLength(ElementaryDataType dt) {
        val lowerName = dt.name?.toLowerCase
        if (lowerName !== null) {
            val maxDigits = maxDigitsIfLimited.get(lowerName)
            if (maxDigits !== null) {
                if (dt.length > maxDigits) {
                    error("Mantissa max be " + maxDigits + " at most for this data type",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
                }
                if (dt.decimals > dt.length) {
                    error("Number of decimals digits cannot exceed number of total digits",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__DECIMALS);
                }
            }
            switch (lowerName) {
            case "time":
                if (dt.length < 0 || dt.length > 3) {
                    error("Fractional seconds must be at least 0 and at most 3 digits",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
                }
            case "timestamp": // similar to default, but allow 0 decimals and max. 3 digits precision
                if (dt.length < 0 || dt.length > 3) {
                    error("Fractional seconds must be at least 0 and at most 3 digits",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
                }
            case "instant": // similar to default, but allow 0 decimals and max. 3 digits precision
                if (dt.length < 0 || dt.length > 3) {
                    error("Fractional seconds must be at least 0 and at most 3 digits",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
                }
            case "number":
                if (dt.length <= 0 || dt.length > 38) {
                    error("Mantissa must be at least 1 and cannot exceed 38 (currently)",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
                }
            case "decimal":
                if (dt.length <= 0) {
                    error("Mantissa must be specified and cannot be 0 for this data type",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
                }
            case "fixedpoint":
                if (dt.length <= 0 || dt.length > 18) {
                    error("Length must be between 1 and 18 for fixed point numbers",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
                } else if (dt.decimals <= 0 || dt.decimals > 15 || dt.decimals > dt.length) {
                    error("Precision must be between 0 and 15 decimals and cannot exceed number of digits for fixed point numbers",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__DECIMALS);
                }
                // String types and binary data types
            case #[ "ascii", "unicode", "uppercase", "lowercase", "binary" ].contains(lowerName): {
                if (dt.minLength < 0) {
                    error("Field min length cannot be negative",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__MIN_LENGTH);
                    return;
                }
                if (dt.minLength > dt.length) {
                    error("Field min length cannot exceed field length",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__MIN_LENGTH);
                    return;
                }
                if (dt.length <= 0 || dt.length > GIGABYTE) {
                    error("Field size must be at least 1 and at most 1 GB",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
                }
                }
            case "raw":
                if (dt.length <= 0 || dt.length > GIGABYTE) {
                    error("Field size must be at least 1 and at most 1 GB",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
                } else {
                    // not good anyway
                    if (BonScriptPreferences.currentPrefs.warnByte)
                        warning("The type \"Raw\" is mapped to the mutable Java class byte []. Use of \"Binary\" is preferred.",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__NAME);
                }
            case "float":
                    if (BonScriptPreferences.currentPrefs.warnFloat)
                        warning("The type \"Float\" is not guaranteed to be read as exactly as written and may be a bad choice in financial applications.",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__NAME)
            case "double":
                    if (BonScriptPreferences.currentPrefs.warnFloat)
                        warning("The type \"Double\" is not guaranteed to be read as exactly as written and may be a bad choice in financial applications.",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__NAME)
            }
        }
    }

    @Check
    def void checkEnumDeprecation(ElementaryDataType dt) {
        if (dt.enumType !== null) {
            if (dt.enumType.isDeprecated) {
                val containingClass = getContainingClass(dt)
                if (containingClass === null || !containingClass.isDeprecated)
                    warning(dt.enumType.name + " is deprecated", BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__ENUM_TYPE)
            }
        }
        if (dt.xenumType !== null) {
            if (dt.xenumType.isDeprecated) {
                val containingClass = getContainingClass(dt)
                if (containingClass === null || !containingClass.isDeprecated)
                    warning(dt.xenumType.name + " is deprecated", BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__XENUM_TYPE)
            }
        }
    }

    static final char DOT = 'c';

    /**
     * Finds the containing ClassDefinition for any EObject by traversing up the containment hierarchy.
     * Returns null if no containing ClassDefinition is found.
     */
    def private ClassDefinition getContainingClass(EObject obj) {
        var container = obj?.eContainer
        while (container !== null) {
            if (container instanceof ClassDefinition)
                return container
            container = container.eContainer
        }
        return null
    }

    def private boolean isSubBundle(String myBundle, String extendedBundle) {
        if (extendedBundle === null)
            return true;  // everything is a sub-bundle of the static data
        if (myBundle === null)
            return false; // something not in a bundle cannot extend a bundle
        if (!myBundle.startsWith(extendedBundle))
            return false; // should be the bundle extended
        // finally check if the bundle names are either equal or the extension is of form '.' QualifiedID
        return (myBundle.length() == extendedBundle.length())
                || ((myBundle.length() > extendedBundle.length()) && (myBundle.charAt(extendedBundle.length()) === DOT));
    }

    // a test for cyclic inheritance
    def static private void checkInheritance(ClassDefinition d, int remaining) {
        if (d.extendsClass?.classRef !== null) {
            if (remaining <= 0)
                throw new Exception("Cyclic inheritance around " + d.name)
            d.extendsClass?.classRef.checkInheritance(remaining - 1)
        }
    }

    @Check
    def void checkClassDefinition(ClassDefinition cd) {
        val s = cd.name;
        if (s !== null) {
            if (!Character.isUpperCase(s.charAt(0))) {
                error("Class names should start with an upper case letter", BonScriptPackage.Literals.CLASS_DEFINITION__NAME);
            }
            if (cd.getPartiallyQualifiedClassName.length > MAX_PQON_LENGTH) {
                error("Partially qualified class name cannot exceed 63 characters length", BonScriptPackage.Literals.CLASS_DEFINITION__NAME);
            }
        }
        if (cd.hazelcastId != 0 && (cd.abstract || cd.isSingleField))
            warning("abstract classes and singleField adapters don't need a classId", BonScriptPackage.Literals.CLASS_DEFINITION__HAZELCAST_ID)

        if (cd.extendsClass !== null) {
            // the extension must reference a specific class (plus optional generics parameters), but not a generic type itself
            if (cd.extendsClass.classRef === null) {
                error("Parent class must be an explicit class, not a generic type", BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
                return;
            } else {
                // check for cyclic dependencies to avoid a stack overflow
                try {
                    cd.checkInheritance(30)     // 30 levels of nesting should be sufficient
                } catch (Exception ex) {
                    error("Cyclic inheritance", BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS)
                    return
                }
                // check the number of generic parameters
                val ClassDefinition parent = cd.extendsClass.classRef
                val EList<GenericsDef> args = parent.genericParameters
                val EList<ClassReference> argValues = cd.extendsClass.classRefGenericParms
                if ((args === null) && (argValues === null)) {
                     // fine
                } else if ((args !== null) && (argValues !== null)) {
                    if (args.size() != argValues.size()) {
                        error("Parameter number mismatch for generics arguments: " + argValues.size() + " parameters found, but " + args.size() + " expected",
                                BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
                    }
                } else if (argValues !== null) {
                    error("Generics arguments found, but extending non-generic class", BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
                } else if (args !== null) {
                    error("Extending generics class, but no generics arguments found", BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
                }
            }
            // the extended class may not be final
            if (cd.extendsClass.classRef.isFinal()) {
                error("Classes max not extend a final class", BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
            }
            // this class cannot be xmlRoot as it extends another one => yes it can, see
//            if (cd.isIsXmlRoot) {
//                error("Classes which extend another one cannot be @XmlRootElement", BonScriptPackage.Literals.CLASS_DEFINITION__IS_XML_ROOT);
//            }
            // the extended class must be in the same bundle or a superbundle
            val myPackage = cd.packageOrNull
            val extendedFromPackage = cd.extendsClass.classRef.packageOrNull
            if (myPackage !== null && extendedFromPackage !== null) {
                if (!isSubBundle(myPackage.getBundle(), extendedFromPackage.getBundle())) {
                    error("Parent classes must be in the same or a superbundle of the current package",
                            BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
                }
            } else {
                warning("Cannot determine package of " + (if (myPackage === null) cd.name else cd.extendsClass.classRef.name)
                        + " +++ " + TreeView.getClassInfo(cd) + " *** " + TreeView.getClassInfo(cd.getExtendsClass().getClassRef()),
                        BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
            }
            // check for cyclic dependencies
            var int depth = 0;
            var boolean haveAnchestorWithAbsoluteRtti = false;
            var anchestor = cd.getExtendsClass().getClassRef();
            while ((depth = depth + 1) < 100 && anchestor !== null) {  // after 100 iterations we assume cyclicity
                if (cd.returnsClassRef !== null && anchestor.returnsClassRef !== null) {
                    if (!inheritsClass(cd.returnsClassRef.lowerBound, anchestor.returnsClassRef.lowerBound)) {
                        error("return object of a subclass must inherit the return class of any superclass, which is not the case for return type "
                                + anchestor.returnsClassRef.lowerBound.name + " of " + anchestor.name,
                                BonScriptPackage.Literals.CLASS_DEFINITION__RETURNS_CLASS_REF);
                    }
                }
                if ((anchestor.getRtti() > 0) && !anchestor.isAddRtti()) {
                    haveAnchestorWithAbsoluteRtti = true;
                }
                anchestor = anchestor.parent
            }
            if (depth >= 100) {
                error("Parent hierarchy is cyclical", BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
            }
            // check that relative rtti may only be given if there is a parent class with a fixed rtti
            if (!haveAnchestorWithAbsoluteRtti && cd.isAddRtti()) {
                error("For relative RTTI definition, at least one anchestor must have an absolute RTTI", BonScriptPackage.Literals.CLASS_DEFINITION__ADD_RTTI);
            }

            // an custom class cannot extend a non-custom class and vice versa, as the freezing stuff etc won't work
            if (cd.externalType !== null) {
                if (cd.extendsClass.classRef.externalType === null)
                    error("Parent classes of external JVM classes must also be external JVM classes",
                            BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
            } else {
                if (cd.extendsClass.classRef.externalType !== null)
                    error("Parent classes of regular classes cannot be external JVM classes",
                            BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
            }
        }

        // check the number of fields, unless noAllFieldsConstructor is set
        if (!cd.isNoAllFieldsConstructor()) {
            // count the fields. We can have 255 at max, due to JVM limitations
            var int numFields = 0;
            var p = cd;
            while (p !== null) {
                // parent class may not have this directive, due to recursive implementation
                if (p.isNoAllFieldsConstructor()) {
                    error("Has to specify noAllFieldsConstructor directive if any of the parent classes uses it! (" + p.name + " does not)",
                            BonScriptPackage.Literals.CLASS_DEFINITION__NAME);
                    return;
                }
                numFields = numFields + p.fields.size
                if (p.getExtendsClass() === null)
                    p = null // break;
                else
                    p = p.getExtendsClass().getClassRef();
            }
            if (numFields > 255) {
                error("More than 255 fields, cannot build all-fields constructor. Use noAllFieldsConstructor directive!",
                        BonScriptPackage.Literals.CLASS_DEFINITION__FIELDS);
            }
        }

        if (cd.pkClass !== null) {
            if (cd.pkClass.isDeprecated && !cd.isDeprecated)
                warning(cd.pkClass.name + " is deprecated", BonScriptPackage.Literals.CLASS_DEFINITION__PK_CLASS)

            // check that there is no conflict with a prior definition
            var p = cd.extendsClass?.classRef
            while (p !== null) {
                if (p.pkClass !== null && p.pkClass != cd.pkClass)
                    error('''Inconsistent redefinition of pk: was defined as «p.pkClass.name» in inherited class «p.name»''',
                        BonScriptPackage.Literals.CLASS_DEFINITION__PK_CLASS)
                p = p.extendsClass?.classRef
            }
            if (cd.pkClass.firstField === null)
                error('''PK class cannot be empty''', BonScriptPackage.Literals.CLASS_DEFINITION__PK_CLASS)
        }

        // do various checks if the class has been defined as freezable or is a child of a freezable one
        if (!cd.unfreezable) {   // no explicit immutability advice
            // may not have mutable fields
            if (cd.fields.exists[datatype.elementaryDataType !== null && "raw".equals(datatype.elementaryDataType.name.toLowerCase)])
                warning("class is not freezable due to mutable fields", BonScriptPackage.Literals.CLASS_DEFINITION__NAME)
            // any type parameters must be freezable as well
            if (cd.genericParameters.exists[extends !== null && !extends.isFreezable])
                warning("class is not freezable due to unfreezable generic references", BonScriptPackage.Literals.CLASS_DEFINITION__NAME)
            if (cd.fields.exists[isArray !== null])
                warning("class is not freezable due to arrays", BonScriptPackage.Literals.CLASS_DEFINITION__NAME)
            if (cd.extendsClass !== null && !cd.extendsClass.freezable)
                warning("class is not freezable due to parent", BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS)
        } else {
            if (cd.doCacheHash) {
                error("Caching the hashcode makes no sense if the class is neither immutable nor can be frozen", BonScriptPackage.Literals.CLASS_DEFINITION__DO_CACHE_HASH)
            }
        }

        // verify settings for custom types. These limitations may be lifted in some future extension
        if (cd.externalType !== null) {
            // currently, if specifying an adapter, "static" must be set, and vice versa
            if (!cd.final) {
                error("Currently external types must be declared as final", BonScriptPackage.Literals.CLASS_DEFINITION__EXTERNAL_TYPE)
            }
            if (!cd.immutable) {
                error("Currently external types must be declared as immutable", BonScriptPackage.Literals.CLASS_DEFINITION__EXTERNAL_TYPE)
            }

            if (cd.singleField) {
                if (cd.rtti != 0)
                    warning("singleField adapters don't need a RTTI value, because the class is just a wrapper", BonScriptPackage.Literals.CLASS_DEFINITION__RTTI)
                if (cd.hazelcastId != 0)
                    warning("singleField adapters don't need a classId value, because the class is just a wrapper", BonScriptPackage.Literals.CLASS_DEFINITION__HAZELCAST_ID)
                // there must be extactly one internal field, independent of externally added attributes
                if (cd.countFields != 1)
                    error("singleField adapters must declare exactly one field (itself or in superclasses), found " + cd.countFields,
                      BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS)
            }
        }
    }

    def private int countFields(ClassDefinition d) {
        if (d.extendsClass?.classRef === null)
            return d.fields.size
        else
            return d.fields.size + d.extendsClass.classRef.countFields
    }

    def private boolean inheritsClass(ClassDefinition myInitialReturnType, ClassDefinition superclassReturnType) {
        var myReturnType = myInitialReturnType
        while (myReturnType !== null) {
            if (myReturnType.equals(superclassReturnType))
                return true;
            myReturnType = myReturnType.parent
        }
        return false;
    }

    // helper function for checkFieldDefinition
    def static int countSameName(ClassDefinition cl,  String myName) {
        cl.fields.filter[name == myName].size
    }

    @Check
    def void checkFieldDefinition(FieldDefinition fd) {
        val s = fd.name
        if (s !== null) {
            if (!Character.isLowerCase(s.charAt(0))) {
                error("field names should start with a lower case letter",
                        BonScriptPackage.Literals.FIELD_DEFINITION__NAME);
            }
        }
        /*
        if (s.length() > 1 && Character.isUpperCase(s.charAt(1)) && fd.getGetter() === null && fd.getSetter() === null) {
            warning("Java beans specification for getter / setter name differs from standard get/setCapsFirst approach. Consider specifying alt names",
                    BonScriptPackage.Literals.FIELD_DEFINITION__NAME);
        }
        if (fd.getGetter() !== null && s.equals("get" + StringExtensions.toFirstUpper(fd.getGetter()))) {
            error("alternate name matches the default name", BonScriptPackage.Literals.FIELD_DEFINITION__GETTER);
        }
        if (fd.getSetter() !== null && s.equals("set" + StringExtensions.toFirstUpper(fd.getSetter()))) {
            error("alternate name matches the default name", BonScriptPackage.Literals.FIELD_DEFINITION__SETTER);
        } */

        // check for unique name within this class and possible superclasses
        val cl = fd.eContainer as ClassDefinition  // Grammar dependency! FieldDefinition is only called from ClassDefinition right now
        if (countSameName(cl, s) != 1) {
            error("field name is not unique within this class",
                    BonScriptPackage.Literals.FIELD_DEFINITION__NAME);
        }
        // check parent classes as well
        var parentClass = cl.getParent
        while (parentClass !== null) {
            if (countSameName(parentClass, s) != 0) {
                error("field occurs in inherited class "
                        + (parentClass.eContainer as PackageDefinition).name + "."
                        + parentClass.name + " already (shadowing not allowed in bonaparte)",
                        BonScriptPackage.Literals.FIELD_DEFINITION__NAME);
            }
            parentClass = parentClass.getParent
        }

        if (fd.required !== null) {
            /*
            // System.out.println("Checking " + s + ": getRequired() = <" + fd.getRequired().toString() + ">");
            // not allowed for typedefs right now
            if (fd.getDatatype() !== null && fd.getDatatype().getReferenceDataType() !== null) {
                error("required / optional attributes not allowed for type definitions: found <" + fd.getRequired().getX().toString() + "> for " + s,
                        BonScriptPackage.Literals.FIELD_DEFINITION__REQUIRED);
            } */
            if ((fd.required.x == XRequired.OPTIONAL) && (fd.datatype !== null)) {
                val dt = fd.datatype.elementaryDataType;
                if (dt !== null && dt.name !== null && Character.isLowerCase(dt.name.charAt(0))) {
                    error("optional attribute conflicts implicit 'required' meaning of lower case data type",
                            BonScriptPackage.Literals.FIELD_DEFINITION__REQUIRED);
                }
            }
        }

        val elemDataType = fd.datatype?.elementaryDataType?.name?.toLowerCase
        if ("array" == elemDataType) {
            // do not allow aggregates for this (XML would fail)
            if (fd.isMap !== null) {
                error("array is an implicit aggregate and cannot be combined with a Map modifier",
                        BonScriptPackage.Literals.FIELD_DEFINITION__IS_MAP);
            }
            if (fd.isSet !== null) {
                error("array is an implicit aggregate and cannot be combined with a Set modifier",
                        BonScriptPackage.Literals.FIELD_DEFINITION__IS_SET);
            }
            if (fd.isList !== null) {
                error("array is an implicit aggregate and cannot be combined with a List modifier",
                        BonScriptPackage.Literals.FIELD_DEFINITION__IS_LIST);
            }
            if (fd.isArray !== null) {
                error("array is an implicit aggregate and cannot be combined with an Array modifier",
                        BonScriptPackage.Literals.FIELD_DEFINITION__IS_ARRAY);
            }
        }

        // deprecated fields should not be required
        if (fd.isDeprecated) {
            if (fd.isAggregate) {
                if (fd.isIsAggregateRequired)
                    error("Required aggregates cannot be @Deprecated", BonScriptPackage.Literals.FIELD_DEFINITION__IS_DEPRECATED);
            } else {
                if (fd.isRequired)
                    error("Required fields cannot be @Deprecated", BonScriptPackage.Literals.FIELD_DEFINITION__IS_DEPRECATED);
            }
        }
    }

    @Check
    def void checkGenericsParameterList(ClassReference ref) {
        if (ref.getClassRef() !== null) {
            if (ref.classRef.isDeprecated) {
                val containingClass = getContainingClass(ref)
                if (containingClass === null || !containingClass.isDeprecated)
                    warning(ref.classRef.name + " is deprecated", BonScriptPackage.Literals.CLASS_REFERENCE__CLASS_REF)
            }
            // verify that the parameters given match the definition of the class referenced
            val requiredParameters = ref.getClassRef().getGenericParameters();
            val providedParameters = ref.getClassRefGenericParms();
            if ((requiredParameters === null) && (providedParameters === null))
                return;  // OK, both have no parameters
            if (requiredParameters === null) {
                // not ok, one is empty, the other not!
                error("list of generic type attributes does not match definition of referenced class, which is a non-generic type",
                        BonScriptPackage.Literals.CLASS_REFERENCE__CLASS_REF_GENERIC_PARMS);
                return;
            }
            if (providedParameters === null) {
                // not ok, one is empty, the other not!
                error("must provide a list of generic type attributes",
                        BonScriptPackage.Literals.CLASS_REFERENCE__CLASS_REF);
                return;
            }
            if (requiredParameters.size() != providedParameters.size()) {
                // not ok, one is empty, the other not!
                error("list of generic type attributes differs in length from definition in referenced class",
                        BonScriptPackage.Literals.CLASS_REFERENCE__CLASS_REF_GENERIC_PARMS);
                return;
            }
//            for (i:  0..< requiredParameters.size) {
//                if (requiredParameters.get(i).getExtends() !== null) {
//                    // provided parameter must be a subclass of the requested one
//                    if (!isSuperClass(requiredParameters.get(i).getExtends(), providedParameters.get(i)))
//                }
//            }
        }
    }


    @Check
    def void checkPropertyUse(PropertyUse pu) {
        if (pu.key.annotationReference === null)
            return; // no check for standard properties
        if (pu.key.isWithArg() || pu.key.isWithMultiArgs()) {
            if (pu.getValue() === null)
                error("the property " + pu.key.name + " has been defined to require a value",    BonScriptPackage.Literals.PROPERTY_USE__KEY);
        } else {
            if (pu.getValue() !== null)
                error("the property " + pu.key.name + " has been defined to not accept a value", BonScriptPackage.Literals.PROPERTY_USE__VALUE);
        }
    }

    @Check
    def void checkArrayModifier(ArrayModifier it) {
        if (mincount > maxcount)
            error("The minimum count cannot be larger than the maximum count",
                    BonScriptPackage.Literals.ARRAY_MODIFIER__MINCOUNT);
    }
    @Check
    def void checkListModifier(ListModifier it) {
        if (mincount > maxcount)
            error("The minimum count cannot be larger than the maximum count",
                    BonScriptPackage.Literals.LIST_MODIFIER__MINCOUNT);
    }
    @Check
    def void checkSetModifier(SetModifier it) {
        if (mincount > maxcount)
            error("The minimum count cannot be larger than the maximum count",
                    BonScriptPackage.Literals.SET_MODIFIER__MINCOUNT);
    }
    @Check
    def void checkMapModifier(MapModifier it) {
        if (mincount > maxcount)
            error("The minimum count cannot be larger than the maximum count",
                    BonScriptPackage.Literals.MAP_MODIFIER__MINCOUNT);
    }

    // if two object references are provides, verify that the second is a subclass of the first, as the generated data type is
    // provided by the first and the second must be storable in the same field
    @Check
    def void checkDataType(DataType it) {
        val lowerBoundOfFirst = objectDataType?.lowerBound
        if (lowerBoundOfFirst !== null && secondaryObjectDataType !== null) {
            // the second must be a subtype of the first!
            if (!lowerBoundOfFirst.isSuperClassOf(secondaryObjectDataType)) {
                error("Secondary data type must be a subclass of the first!", BonScriptPackage.Literals.DATA_TYPE__OR_SECONDARY_SUPER_CLASS)
            }
        }

        // check the extra parameter, it may be supplied if and only if the referenced type has an adapter with that flag set!
        if (objectDataType?.classRef !== null) {
            if (objectDataType.classRef.needExtraParam) {
                if (extraParameter === null && extraParameterString === null)
                    error("Need extra parameter for a reference to " + objectDataType.classRef.name, BonScriptPackage.Literals.DATA_TYPE__EXTRA_PARAMETER)
            } else {
                if (extraParameter !== null || extraParameterString !== null)
                    error("Extra parameter not requested by referenced object" + objectDataType.classRef.name, BonScriptPackage.Literals.DATA_TYPE__EXTRA_PARAMETER)
            }
            // cannot reference an Xml root element
            if (objectDataType.classRef.root.isIsXmlRoot) {
                error("Cannot reference an xmlRoot Element", BonScriptPackage.Literals.DATA_TYPE__OBJECT_DATA_TYPE)
            }
        }
        // cannot reference an Xml root element
        if (secondaryObjectDataType?.classRef !== null) {
           if (secondaryObjectDataType.classRef.root.isIsXmlRoot) {
                error("Cannot reference an xmlRoot Element", BonScriptPackage.Literals.DATA_TYPE__SECONDARY_OBJECT_DATA_TYPE)
            }
        }
    }

    @Check
    def void checkComparableFields(ComparableFieldsList fl) {
        for (f : fl.field) {
            // f may not be an aggregate, and may not be "Object", and not point to a Class which by itself is not a Comparable
            // also, f must be "required"
            // no check here for typedefs, as e resolve these later
            if (f.aggregate)
                error("orderedBy fields cannot be an aggregate (array / Map / List / Set): " + f.name, BonScriptPackage.Literals.COMPARABLE_FIELDS_LIST__FIELD)
            if (f.datatype.elementaryDataType !== null) {
                val type = f.datatype.elementaryDataType.name.toFirstLower
                if (type == "raw" || type == "binary" || type == "object")
                    error("orderedBy fields cannot be of type raw / binary / object: " + f.name, BonScriptPackage.Literals.COMPARABLE_FIELDS_LIST__FIELD)
            }
        }
    }


    @Check
    def void checkEnumIDsAndTokens(EnumDefinition e) {
        // any used ID or token may be 63 characters max length.
        val idSet = new HashSet<String>(50)
        if (e.values !== null && !e.values.empty) {
            for (inst : e.values) {
                if (inst.length > 63) {
                    error("ID is too long (max 63 characters allowed, found " + inst.length + ")", BonScriptPackage.Literals.ENUM_DEFINITION__VALUES)
                }
                if (!idSet.add(inst)) {
                    error("duplicate ID in enum: " + inst, BonScriptPackage.Literals.ENUM_DEFINITION__VALUES)
                }
            }
        }
        // No ID or token may be used twice
        if (e.avalues !== null && !e.avalues.empty) {
            val tokenSet = new HashSet<String>(50)
            for (inst : e.avalues) {
                if (!idSet.add(inst.name))
                    error("duplicate ID in enum: " + inst.name, BonScriptPackage.Literals.ENUM_DEFINITION__AVALUES)
                if (!tokenSet.add(inst.token))
                    error("duplicate token in enum: " + inst.token, BonScriptPackage.Literals.ENUM_DEFINITION__AVALUES)
            }
        }
    }

    @Check
    def void checkEnumAlphaValueDefinition(EnumAlphaValueDefinition aval) {
        if (aval.name.length > 63)
            error("ID is too long (max 63 characters allowed, found " + aval.name.length + ")", BonScriptPackage.Literals.ENUM_ALPHA_VALUE_DEFINITION__NAME)
        if (aval.token.length > 63)
            error("Token is too long (max 63 characters allowed, found " + aval.token.length + ")", BonScriptPackage.Literals.ENUM_ALPHA_VALUE_DEFINITION__TOKEN)
    }

    // a test for cyclic inheritance
    def static private void checkInheritance(XEnumDefinition e, int remaining) {
        if (e.extendsXenum !== null) {
            if (remaining <= 0)
                throw new Exception("Cyclic inheritance around " + e.name)
            e.extendsXenum.checkInheritance(remaining - 1)
        }
    }

    @Check
    def void checkXEnum(XEnumDefinition e) {
        try {
            e.checkInheritance(20)      // 20 levels of nesting should be sufficient
        } catch (Exception ex) {
            error("Cyclic inheritance", BonScriptPackage.Literals.XENUM_DEFINITION__EXTENDS_XENUM)
            return
        }
        if (!e.isDeprecated) {
            if (e.myEnum !== null && e.myEnum.isDeprecated)
                warning(e.myEnum.name + " is deprecated", BonScriptPackage.Literals.XENUM_DEFINITION__MY_ENUM)
            if (e.extendsXenum !== null && e.extendsXenum.isDeprecated)
                warning(e.extendsXenum.name + " is deprecated", BonScriptPackage.Literals.XENUM_DEFINITION__EXTENDS_XENUM)
        }
        if (e.myEnum !== null) {
            if (e.myEnum.avalues === null || e.myEnum.avalues.empty) {
                error(e.myEnum.name + " does not implement Tokenizable", BonScriptPackage.Literals.XENUM_DEFINITION__MY_ENUM)
                return
            }
            if (e.extendsXenum !== null) {
                // check that we don't exceed the length of the parent
                val mine = getInternalMaxLength(e.myEnum, 0)
                val old = getOverallMaxLength(e.extendsXenum)
                if (mine > old) {
                    error("Token longer than parent allows: here " + mine + " parent has " + old, BonScriptPackage.Literals.XENUM_DEFINITION__MY_ENUM)
                    return
                }
                // also, the extended one cannot be final
                if (e.extendsXenum.final) {
                    error("Cannot extend a final xenum", BonScriptPackage.Literals.XENUM_DEFINITION__EXTENDS_XENUM)
                    return
                }
            } else if (e.maxlength > 0) {
                // have internal limit
                val mine = getInternalMaxLength(e.myEnum, 0)
                if (mine > e.maxlength) {
                    error("enum tokens are longer than specified: here " + mine + ", limit = " + e.maxlength, BonScriptPackage.Literals.XENUM_DEFINITION__MAXLENGTH)
                    return
                }
            }
        }
    }

    @Check
    def void checkImplements(InterfaceListDefinition il) {
        if (il.ilist !== null) {
            for (intrface : il.ilist)
                if (!intrface.isInterface)
                    error('''«intrface.qualifiedName» is not an interface''', BonScriptPackage.Literals.INTERFACE_LIST_DEFINITION__ILIST)
        }
    }

    def private void hasMoreThan(EnumDefinition e, int entries) {
        var num = 0
        if (e.avalues !== null && e.avalues.size > 0)
            num = e.avalues.size
        if (e.values !== null && e.values.size > 0)
            num = e.values.size
        if (num > entries)
            error("enum has more than " + entries + " instances", BonScriptPackage.Literals.ENUM_SET_DEFINITION__MY_ENUM)
    }

    @Check
    def void checkEnumSetDefinition(EnumSetDefinition es) {
        if ("String" == es.indexType) {
            // validate that the referenced enum has alpha, and a token size of 1
            if (es.myEnum?.avalues.nullOrEmpty) {
                error('''String type enum sets must reference enums with tokens''', BonScriptPackage.Literals.ENUM_SET_DEFINITION__INDEX_TYPE)
                return
            }
            // check that all tokens have size 1
            var boolean allOK = true
            for (z : es.myEnum.avalues) {
                if (z.token.length != 1)
                    allOK = false
            }
            if (!allOK)
                error('''String type enum sets must reference enums which have tokens of length 1 only''', BonScriptPackage.Literals.ENUM_SET_DEFINITION__MY_ENUM)
        } else if ("byte" == es.indexType) {
            // may have at max 7 instances
            es.myEnum.hasMoreThan(7)
        } else if ("short" == es.indexType) {
            // may have at max 15 instances
            es.myEnum.hasMoreThan(15)
        } else if (es.indexType === null || "int" == es.indexType) {
            // may have at max 31 instances
            es.myEnum.hasMoreThan(31)
        } else if ("long" == es.indexType) {
            // may have at max 63 instances
            es.myEnum.hasMoreThan(63)
        }
    }

    @Check
    def void checkXEnumSetDefinition(XEnumSetDefinition es) {
        val tokenLength = getOverallMaxLength(es.myXEnum)
        if (tokenLength != 1)
            error("max length of tokens must be 1, but is " + tokenLength, BonScriptPackage.Literals.XENUM_SET_DEFINITION__MY_XENUM)
    }

    @Check
    def void checkPackageDefinition(PackageDefinition p) {
        if (p.name == "xs" || p.name == "xsi" || p.name == "bon")
            error("The package IDs xs, xsi and bon are reserved", BonScriptPackage.Literals.PACKAGE_DEFINITION__NAME)
        if (p.name.toLowerCase.startsWith("xml"))
            warning("Package names starting with xml are discouraged due to resulting XML namespace prefix conflicts", BonScriptPackage.Literals.PACKAGE_DEFINITION__NAME)

        if (p.hazelcastFactoryId != 0) {
            val usedClassIds = new HashMap<Integer,String>(50)
            // user makes use of numeric class identifiers, support it by some extra plausis
            for (cls : p.classes) {
                // if this class uses the same factoryId, then check for uniqueness
                if (cls.hazelcastId == 0) {
                    if (!cls.abstract && !cls.isSingleField)
                        warning("No classId has been specified for " + cls.name, BonScriptPackage.Literals.PACKAGE_DEFINITION__HAZELCAST_FACTORY_ID)
                } else {
                    val duplicate = usedClassIds.put(cls.hazelcastId, cls.name)
                    if (duplicate !== null)
                        error("classes " + duplicate + " and " + cls.name + " use the same classId " + cls.hazelcastId, BonScriptPackage.Literals.PACKAGE_DEFINITION__HAZELCAST_FACTORY_ID)
                }
            }
        }
    }
}
