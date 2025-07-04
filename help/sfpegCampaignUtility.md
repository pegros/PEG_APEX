
# ![Logo](/media/Logo.png) &nbsp; SFPEG Campaign Utility

## Introduction

The **sfpegCampaign_UTL** Apex utility class (called from Campaign and CampaignMember
Apex triggers) enables to implement some usual business logic missing in standard
Salesforce for Campaign management:
* propagation of Campaign member counts and budgets within Campaign hierarchy
* initialization of Campaign Member statuses for each new Campaign
* control of the type of members allowed for a Campaign

The proposed approach is to configure such features on a per CampaignMember RecordType
basis to support a variety of use cases. This value is assumed to be set at creation on the
Campaign record via the `CampaignMemberRecordTypeId` field and automatically set on the
associated CampaignMember records afterwards.


## Installation

It may be installed and upgraded as the `sfpegApex-campaigns` unlocked package directly
on your Org via the installation link provided in the [release notes](#release-notes).

⚠️ It requires the **[sfpegApex-debug](/help/sfpegDebugUtility.md)** package to be already installed on
your Org (as it relies on it for debug logs).

After installation, you need to register a few `sfpegCampaignRT` custom
metadata records to configure the Campaign trigger logic triggered on a per
RecordType basis.


## Solution Principles

### CampaignMember RecordType Configuration

The adopted approach is to configure the behaviour of this framework on a per `CampaignMember` RecordType basis.
This configuration is done by defining a `sfpegCampaignMbrRT` custom metadata record for each RecordType
for which some or all of the proposed logic should be applied.

Their `Label` and `Name` of each metadata record should match the `Label`and `DeveloperName`of the CampaignMember record type
to which their other properties (e.g. The `CM Types Allowed`, `CM Statuses`) are applied.

![Configuration metadata per CampaignMemver RT](/media/sfpegCampaignMetadata.png)

⚠️ Pay attention to the `DeveloperName` which is the information used by the implemented logic to match
record RecordTypes and metadata configuration. 

ℹ️ RecordType information is fetched by the provided trigger logic from :
* the `RecordTypeId` field on the `CampaignMember` records
* the `CampaignMemberRecordTypeId` field on the `Campaign` records

⚠️ Beware of the 2 `RecordType`fields available on the Campaign records!

![RecordTypes on Campaign record](/media/sfpegCampaignRTs.png)


### Hierarchy Propagation

In standard Salesforce, Campaign hierarchies may be defined (via `ParentId` field) and a wide range of
numeric and currency fields are automatically rolled up in the hierarchy.

![Campaign Hierarchy](/media/sfpegCampaignHierarchy.png)

However, some Campaign rolled-up fields are not automatically computed and require manual input, e.g.
`BudgetedCost`, `NumberSent`, `ActualCost` or `ExpectedRevenue`.

The proposed feature enables to define custom rollup fields on the `Campaign` object based on the 
`CampaignMember` related list to automatically evaluate all or some of these fields from related
CampaignMember records (e.g. by counting all members in certains status or aggregating individual
member costs e.g. based on the communication channel used) and then copy their values in the standard
fields used in the standard hierarchy rollup mechanism.

The configuration should be done in the `Hierarchy Propagation` field of the `sfpegCampaignMbrRT`
metadata record, as a simple JSON map of target / source API field names, e.g.
```
{
  "NumberSent":"Members__c",
  "ActualCost":"MemberCosts__c"
}
```

In this example,
* the `Members__c` custom rollup summary field counts all direct members of a Campaign and is
copied into the standard `NumberSent` field for hierarchy propagation
* the `MemberCosts__c` custom rollup summary field computes the sum of a custom `Cost__c` currency 
of all direct members of a Campaign and is copied into the standard `ActualCost` field for hierarchy propagation

⚠️ Using such custom rollup summary fields enables to enforce an update on the Campaign related to the 
CampaignMember being created / updated / deleted and thus the propagation of the values.
* When choosing a configuration like `{"NumberSent":"NumberOfContacts"}`, the propagation only
happens when the Campaign records are actually updated. No Campaign trigger is indeed executed upon
`NumberOfContacts` update upon new CampaignMember creation.
* When relying on a `count` or `sum` rollup summary field, the relmated Campaign records are actually updated
and the propagation takes place automatically.


### Campaign Member Statuses Initialization

Within Salesforce, the configuration of the `Status` values for the `CampaignMember` object is very special.
The set of applicable values to a `CampaignMember` record indeed comes from the `CampaignMemberStatus` records
related to the parent `Campaign` record (and not from standard setup configuration).

By default, 2 values are automatically created (`Sent`and `Responded`) and manual update on the `CampaignMemberStatus`
related list is required for each Campaign record requiring different status values.

The proposed feature enables to define a set of `Status` values per `CampaignMember` RecordType and automatically
initialize the `CampaignMemberStatus` records for each Campaign referencing this RecordType via its
`CampaignMemberRecordTypeId` field.

In the page below, this is set via the `Campaign Member Type` input (and not the `Campaign Record Type` one).
![RecordTypes on Campaign record](/media/sfpegCampaignRTs.png)

The configuration should be done via the `CM Statuses` and `CM Statuses  (after cleaning)` properties
of the `sfpegCampaignMbrRT` metadata record, as simple JSON list of `CampaignMemberStatus` objects, e.g.
```
[
  {"HasResponded":true,"IsDefault":true,"Label":"Status 3","SortOrder":3},
  {"HasResponded":true,"IsDefault":false,"Label":"Status 4","SortOrder":4}
]
```

If only additional status values are required, only the `CM Statuses` property needs to be set.
Its condfigured values are then added to the default `Sent`and `Responded` values.

If default values need to be removed, reordered... the second `CM Statuses  (after cleaning)`
property is required. Registering values in this propety triggers the deletion of the default values 
and enables e.g. to reuse their `SortOrder` values for other custom values.

The implemented logic then successively 
* inserts the new values provided by `CM Statuses`,
* deletes the preexisting default 
* inserts the new values values provided by `CM Statuses  (after cleaning)` 

⚠️ **Beware** that, at any point of time in this process, there should be:
* only one value for a given `SortOrder`
* always be a value with `IsDefault`set to `true`

You may encounter the following exception if these conditions are not met:
```Insert failed. First exception on row 0; first error: DUPLICATE_VALUE, duplicate value found: <unknown> duplicates value on record with id: <unknown>```

As an example, you may set:
* `CM Statuses` to register steps 3 and 4 and remove the `IsDefault` on the default `Sent` value
```
[
  {"HasResponded":true,"IsDefault":true,"Label":"Step 3","SortOrder":3},
  {"HasResponded":true,"IsDefault":false,"Label":"Step 4","SortOrder":4}
]
```
* `CM Statuses  (after cleaning)` to triger the removal of the default `Sent`and `Responded` values, 
replace them with steps 1 and 2 and reset the `IsDefault` on step 1
```
[
  {"HasResponded":false,"IsDefault":true,"Label":"Step 1","SortOrder":1},
  {"HasResponded":false,"IsDefault":false,"Label":"Step 2","SortOrder":2}
]
```


### Member Type Control

Within Salesforce, it is possible to add various types of members to a Campaign, i.e. `Lead`, `Contacts`
or even `Accounts`.

However, for some types of campaigns, only certains types of members should be included. E.g. prospection campaigns
should only target `Leads`, whereas client relationship campaigns should target onmly `Contacts` or even `Account`
in case of B2B.

The proposed feature enables to define the list of object types allowed when creating a `CampaignMember`
record (based on its `RecordTypeId` coming form the related `Campaign`).

The configuration should be done in the `CM Types Allowed` field of the `sfpegCampaignMbrRT`
metadata record, as a simple multi-picklist-like selection of allowed Object names, e.g.
* `Lead;Contact` to allowLeads and Contacts as members
* `Account` to allow only Accounts

ℹ️ Special configuration is to define a special _NoMember_ RecordType on the `CampaignMember` object
and register a `sfpegCampaignMbrRT` record for it with an empty `CM Types Allowed` property.
* When chosing this RecordType as `CampaignMemberRecordTypeId` on a Campaign record, this enables to prevent
the creation of any related `CampaigMember` record.
* This may be useful for _root_ or _parent_ campaigns defined in a Campaign hierarchy only for organisation or
reporting purposes. 

### Logic Bypass

If needed, you may also bypass part or all of the implemented `Campaign` and/or `CampaignMember` trigger
logic by checking the proper flags in the `sfpegCampaignSettings` custom setting.

![Campaign Setting](/media/sfpegCampaignSetting.png)

## Package Content

All the required metadata is available in the **sfpegCampaignUtility** folder, which contains
* its `sfpegCampaignAfterInsert`, `sfpegCampaignBeforeUpdate` and `sfpegCampaignMemberBeforeInsert` triggers
* the `sfpegCampaign_UTL` utility class (implementing all the business logic)
* the `sfpegCampaignSetting__c` hierarchy Custom Setting (for trigger / logic bypasses)
* the `sfpegCampaignMbrRT__mdt` Custom Metadata for RecordType based configuration
* some Custom Labels (with `sfpegCampaignMember...` prefix) for some error messages raised by the business logic
* the `sfpegCampaign_UTL_TST` Apex test class with supporting `sfpegTestRT` CampaignMember Record Type 
and `sfpegCampaignTest` Permission Set 


## Technical Details

⚠️ When deploying this package, Lead, Account, Contact, Campaign, CampaignMember records are created by the test class.
It may be necessary to bypass all business rules implemented in the Org when deploying the package on it
(the user deploying the package should have bypasses activated).

⚠️ If you want to get Apex logs related to the included triggers, please remeber to actually configure the 
max logging level in the `sfpegDebugSetting` custom setting (see **[sfpegApex-debug](/help/sfpegDebugUtility.md)**
for more information)


## Release Notes

### July 2025 - v1.0
* First version
* Install it from [here ⬇️](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tJ7000000xH6oIAE).
