
package Zonemaster::Backend::ErrorMessages;


use Readonly;
use Locale::TextDomain qw[Zonemaster-Backend];

Readonly my @CUSTOM_MESSAGES_CONFIG => (
    {
        pattern => "/(domain|hostname)",
        config => {
            string => {
                pattern => N__ 'The domain name character(s) are not supported'
            }
        }
    },
    {
        pattern => "/nameservers/\\d+/ip",
        config => {
            string => {
                pattern => N__ 'Invalid IP address'
            }
        }
    },
    {
        pattern => "/nameservers/\\d+/ns",
        config => {
            string => {
                pattern => N__ 'The domain name character(s) are not supported'
            }
        }
    },
    {
        pattern => "/ds_info/\\d+/keytag",
        config => {
            integer => {
                type => N__ 'Keytag should be a positive integer',
                minimum => N__ 'Keytag should be a positive integer'
            }
        }
    },
    {
        pattern => "/ds_info/\\d+/algorithm",
        config => {
            integer => {
                type => N__ 'Algorithm should be a positive integer',
                minimum => N__ 'Algorithm should be a positive integer'
            }
        }
    },
    {
        pattern => "/ds_info/\\d+/digtype",
        config => {
            integer => {
                type => N__ 'Digest type should be a positive integer',
                minimum => N__ 'Digest type should be a positive integer'
            }
        }
    },
    {
        pattern => "/ds_info/\\d+/digest",
        config => {
            string => {
                pattern => N__ 'Invalid digest format'
            }
        }
    },
    {
        pattern => "/language",
        config => {
            string => {
                pattern => N__ 'Invalid language tag format'
            }
        }
    },
    {
        pattern => ".*",
        config => {
            object => {
                required => N__ 'Missing property'
            }
        }
    }
);

sub custom_messages_config {
    return \@CUSTOM_MESSAGES_CONFIG;
}
